local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local LogService = game:GetService("LogService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Maid = require(ReplicatedStorage.package.Maid)

type References = {
	contents: { [string]: boolean },
	targets: { Instance | string },
	visited: { [any]: boolean },
	maid: Maid.Maid,
}

type FetchReport = {
	failed: { [string]: string },
	permissions: { [string]: boolean },
	seen: { [string]: boolean },
}

export type AssetPreloader = {
	Preload: (playerGui: PlayerGui) -> string,
}

local AssetPreloader: AssetPreloader = {} :: AssetPreloader

local REFERENCES_PER_BATCH: number = 50 -- keeps requests and temporary instances in manageable groups
local REPORT_LINES_PER_MESSAGE: number = 20 -- limits duplicate Output rows so native share-access messages stay visible
-- SurfaceAppearance and MaterialVariant properties that can reference texture assets.
local PBR_PROPERTIES: { string } = {
	"ColorMap",
	"ColorMapContent",
	"EmissiveMaskContent",
	"MetalnessMap",
	"MetalnessMapContent",
	"NormalMap",
	"NormalMapContent",
	"RoughnessMap",
	"RoughnessMapContent",
	"TexturePackContent",
}
local preloading: boolean = false -- prevents overlapping scans on this client

local function isPermissionFailure(message: string): boolean
	local lower: string = message:lower()

	return lower:find("not authorized", 1, true) ~= nil
		or lower:find("access permission", 1, true) ~= nil
		or lower:find("no permission", 1, true) ~= nil
		or lower:find("not allowed to be forked", 1, true) ~= nil
end

local function getAssetId(message: string): string?
	return message:match("rbxassetid://(%d+)")
		or message:match("asset id (%d+)")
		or message:match("Asset (%d+) ")
		or message:match("[?&]id=(%d+)")
end

local function getContentKind(key: string, inherited: string?): string?
	local lower: string = key:lower()
	if lower:find("animation", 1, true) then
		return "Animation"
	end
	if lower:find("sound", 1, true) or lower:find("audio", 1, true) then
		return "Sound"
	end
	if lower:find("image", 1, true) or lower:find("icon", 1, true) or lower == "uri" then
		return "ImageLabel"
	end

	return inherited
end

local function addContent(references: References, value: unknown, kind: string?): ()
	if typeof(value) == "Content" then
		local contentValue: any = value
		value = contentValue.SourceType == Enum.ContentSourceType.Uri and contentValue.Uri or nil
	end
	if typeof(value) ~= "string" then
		return
	end
	local content: string = value :: string
	if
		content == ""
		or content:match("^rbxassetid://0+$")
		or not (content:match("^rbx[%w]+://") or content:match("^https?://"))
	then
		return
	end

	local key: string = `{kind or "Content"}|{content}`
	if references.contents[key] then
		return
	end
	references.contents[key] = true
	if kind ~= "Animation" and kind ~= "Sound" and kind ~= "ImageLabel" then
		table.insert(references.targets, content)

		return
	end

	local target: Instance = Instance.new(kind)
	target.Name = "PreloadAllReference"
	if target:IsA("Animation") then
		target.AnimationId = content
	elseif target:IsA("Sound") then
		target.SoundId = content
	elseif target:IsA("ImageLabel") then
		target.Image = content
	end

	references.maid:GiveTask(target)
	table.insert(references.targets, target)
end

local function collectValues(references: References, value: any, kind: string?): ()
	if typeof(value) ~= "table" then
		addContent(references, value, kind)

		return
	end
	if references.visited[value] then
		return
	end
	references.visited[value] = true
	for key: any, child: any in value do
		local childKind: string? = getContentKind(tostring(key), kind)
		if
			childKind
			and (typeof(child) == "number" or typeof(child) == "string")
			and (typeof(key) == "number" or tostring(key):lower():match("id[s]?$") ~= nil)
			and tostring(child):match("^%d+$")
			and tonumber(child) > 0
		then
			addContent(references, `rbxassetid://{child}`, childKind)
		else
			collectValues(references, child, childKind)
		end
	end
end

local function collectReferences(references: References, roots: { Instance }): ()
	for _, root: Instance in roots do
		for index: number, instance: Instance in root:GetDescendants() do
			if instance:IsA("SurfaceAppearance") or instance:IsA("MaterialVariant") then
				for _, property: string in PBR_PROPERTIES do
					local success: boolean, value: any = pcall(function(): any
						return (instance :: any)[property]
					end)
					if success then
						local kind: string? = if property == "TexturePackContent" then nil else "ImageLabel"

						addContent(references, value, kind)
					end
				end
			end
			for _, value: any in instance:GetAttributes() do
				addContent(references, value, nil)
			end
			if index % 1000 == 0 then
				task.wait()
			end
		end
	end

	for _, module: Instance in ReplicatedStorage.shared.config:GetChildren() do
		if not module:IsA("ModuleScript") then
			continue
		end

		local success: boolean, result: any = pcall(require, module)
		if success then
			collectValues(references, result, nil)
		else
			warn(`[preloadAll] Could not read {module:GetFullName()}: {result}`)
		end
	end

	local SFX = require(ReplicatedStorage.util.Core.SFX)

	collectValues(references, SFX.Sounds, "Sound")
end

local function preloadTargets(targets: { Instance | string }, report: FetchReport, source: string): ()
	local success: boolean, errorMessage: any = pcall(function(): ()
		ContentProvider:PreloadAsync(targets, function(content: string, status: Enum.AssetFetchStatus): ()
			if content == "" or content:match("^rbxassetid://0+$") then
				return
			end

			report.seen[content] = true
			if status ~= Enum.AssetFetchStatus.Success then
				report.failed[content] = status.Name
			end
		end)
	end)
	if not success then
		warn(`[preloadAll] {source}: {errorMessage}`)
	end
end

function AssetPreloader.Preload(playerGui: PlayerGui): string
	if preloading then
		return "preloadAll is already running on this client."
	end
	preloading = true
	local maid: Maid.Maid = Maid.new()
	local references: References = { contents = {}, targets = {}, visited = {}, maid = maid }
	local report: FetchReport = { failed = {}, permissions = {}, seen = {} }
	local roots: { Instance } = { ReplicatedStorage, SoundService, ReplicatedFirst, playerGui, Lighting }
	local startedAt: number = os.clock()
	maid:GiveTask(LogService.MessageOut:Connect(function(message: string): ()
		if not isPermissionFailure(message) then
			return
		end

		local assetId: string = getAssetId(message) :: any
		if assetId then
			report.permissions[assetId] = true
		end
	end))

	print(
		`[preloadAll] Client scan: place {game.PlaceId}, universe {game.GameId}. Keep native permission errors visible.`
	)
	local success: boolean, errorMessage: any = xpcall(function(): ()
		collectReferences(references, roots)
		for _, root: Instance in roots do
			print(`[preloadAll] Loading {root:GetFullName()}`)

			preloadTargets({ root }, report, root:GetFullName())
		end
		print(`[preloadAll] Loading {#references.targets} additional config/attribute/PBR references`)
		for first: number = 1, #references.targets, REFERENCES_PER_BATCH do
			local batch: { Instance | string } = {}
			for index: number = first, math.min(first + REFERENCES_PER_BATCH - 1, #references.targets) do
				table.insert(batch, references.targets[index])
			end

			preloadTargets(batch, report, "configured assets")
			task.wait()
		end
	end, debug.traceback)

	maid:DoCleaning()
	preloading = false
	if not success then
		warn(`[preloadAll] Scan interrupted: {errorMessage}`)

		return "preloadAll failed. See Output for details."
	end

	local failed: { string } = {}
	local permissions: number = 0
	local total: number = 0
	for _ in report.seen do
		total += 1
	end
	for content: string in report.failed do
		table.insert(failed, content)
	end

	table.sort(failed)
	for first: number = 1, #failed, REPORT_LINES_PER_MESSAGE do
		local lines: { string } = { "[preloadAll] Failed assets; use native permission errors to share access:" }
		for index: number = first, math.min(first + REPORT_LINES_PER_MESSAGE - 1, #failed) do
			local content: string = failed[index]
			local assetId: string? = getAssetId(content)
			local denied: boolean = assetId ~= nil and report.permissions[assetId] == true
			if denied then
				permissions += 1
			end

			table.insert(lines, `{denied and "NO ACCESS" or "FAILED"} {content} ({report.failed[content]})`)
		end

		warn(table.concat(lines, "\n"))
	end

	local seconds: number = math.round((os.clock() - startedAt) * 10) / 10
	local summary: string =
		`Client: {total} unique assets checked, {#failed} failed ({permissions} permission denials), {seconds}s.`
	print(`[preloadAll] {summary}`)

	return summary
end

return AssetPreloader
