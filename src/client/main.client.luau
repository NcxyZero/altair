--!nocheck
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local ClientInitConfig = require(StarterPlayer.StarterPlayerScripts.clientConfig.ClientInitConfig)
local Logger = require(ReplicatedStorage.util.Logger)

local path = {}
path.controller = {}
path.module = {}
path.local_tag = {}
path.tag = {}

local moduleTags = {}
local moduleTagsLocal = {}
local tags = {}
local loadFirst = {}
local load = {}

for _index: number, folder: Folder in script.Parent:GetChildren() do
	if table.find(ClientInitConfig, folder.Name) then
		continue
	end

	if not folder:IsA("Folder") then
		continue
	end

	for _index: number, module: ModuleScript in folder:GetDescendants() do
		if not module:IsA("ModuleScript") then
			continue
		end

		if module.Name:lower():find("template") then
			continue
		end

		local success: boolean, required: unknown = xpcall(function(): ()
			return require(module)
		end, function(err: string): string
			return debug.traceback(err)
		end)

		if not success then
			Logger.warn(`Failed to load module {module:GetFullName()}: {required}`)
			continue
		end

		if typeof(required) ~= "table" then
			continue
		end

		local moduleType: string = required.type or "module"

		if moduleType == "controller" then
			if required.index then
				loadFirst[required.index] = required
			else
				table.insert(load, required)
			end
		end

		if moduleType == "tag" then
			moduleTags[module.Name] = required
		elseif moduleType == "local_tag" then
			moduleTagsLocal[module.Name] = required
		else
			path[moduleType][module.Name] = required
		end
	end
end

local function InitController(required: unknown): ()
	required.path = path

	local Init: ((unknown?) -> unknown?)? = required.Init
	if Init then
		local success: boolean, err: unknown = xpcall(function(): ()
			Init(required)
		end, function(err2: string): string
			return debug.traceback(err2)
		end)

		if not success then
			Logger.warn(`Failed to initialize controller {required.type or "unknown"}: {err}`)
		end
	end
end

local function StartController(required: unknown): ()
	local Start: ((unknown?) -> unknown?)? = required.Start
	if Start then
		local success: boolean, err: unknown = xpcall(function(): ()
			Start(required)
		end, function(err2: string): string
			return debug.traceback(err2)
		end)

		if not success then
			Logger.warn(`Failed to start controller {required.type or "unknown"}: {err}`)
		end
	end
end

local function InitTag(required: unknown): ()
	local tag: string = required.tag
	if not tag then
		Logger.warn("Tag not specified for required module:", required)
		return
	end

	local new: ((Instance) -> unknown)? = required.new
	if not new then
		Logger.warn("New function not specified for tag module:", required)
		return
	end

	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance: Instance): ()
		local class: unknown = new(instance, path)

		if class then
			class.path = path
			tags[instance] = class

			path.tag[instance] = class
		end
	end)

	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance: Instance): ()
		if tags[instance] and tags[instance].Destroy then
			tags[instance]:Destroy(instance)
			tags[instance] = nil
		end

		path.tag[instance] = nil
	end)

	for _index: number, instance: Instance in CollectionService:GetTagged(tag) do
		task.spawn(function(): ()
			local class: unknown = new(instance, path)

			if class then
				class.path = path
				tags[instance] = class

				path.tag[instance] = class
			end
		end)
	end
end

local function InitLocalTag(required: unknown): ()
	local tag: string = required.tag
	if not tag then
		Logger.warn("Tag not specified for local tag module:", required)
		return
	end

	local new: ((Instance) -> unknown)? = required.new
	if not new then
		Logger.warn("New function not specified for local tag module:", required)
		return
	end

	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance: Instance): ()
		if not Players.LocalPlayer:IsAncestorOf(instance) then
			if not Players.LocalPlayer.Character or not Players.LocalPlayer.Character:IsAncestorOf(instance) then
				return
			end
		end

		local class: unknown = new(instance, path)

		if class then
			class.path = path
			tags[instance] = class
			path.local_tag[instance] = class
		end
	end)

	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance: Instance): ()
		if tags[instance] and tags[instance].Destroy then
			tags[instance]:Destroy(instance)
			tags[instance] = nil
		end
	end)

	for _index: number, instance: Instance in CollectionService:GetTagged(tag) do
		task.spawn(function(): ()
			if not Players.LocalPlayer:IsAncestorOf(instance) then
				if not Players.LocalPlayer.Character or not Players.LocalPlayer.Character:IsAncestorOf(instance) then
					return
				end
			end

			local class: unknown = new(instance, path)

			if class then
				class.path = path
				tags[instance] = class
				path.local_tag[instance] = class
			end
		end)
	end
end

for _index: number, required: unknown in loadFirst do
	local success: boolean, err: unknown = xpcall(function(): ()
		InitController(required)
	end, function(err2: string): string
		return debug.traceback(err2)
	end)

	if not success then
		Logger.warn(`Failed to initialize priority controller {required.type or "unknown"}: {err}`)
	end
end

for _index: number, required: unknown in load do
	local success: boolean, err: unknown = xpcall(function(): ()
		InitController(required)
	end, function(err2: string): string
		return debug.traceback(err2)
	end)

	if not success then
		Logger.warn(`Failed to initialize controller {required.type or "unknown"}: {err}`)
	end
end

for _index: number, required: unknown in moduleTags do
	task.spawn(InitTag, required)
end

for _index: number, required: unknown in moduleTagsLocal do
	task.spawn(InitLocalTag, required)
end

for _index: number, required: unknown in loadFirst do
	local success: boolean, err: unknown = xpcall(function(): ()
		StartController(required)
	end, function(err2: string): string
		return debug.traceback(err2)
	end)

	if not success then
		Logger.warn(`Failed to start priority controller {required.type or "unknown"}: {err}`)
	end
end

for _index: number, required: unknown in load do
	local success: boolean, err: unknown = xpcall(function(): ()
		StartController(required)
	end, function(err2: string): string
		return debug.traceback(err2)
	end)

	if not success then
		Logger.warn(`Failed to start controller {required.type or "unknown"}: {err}`)
	end
end

Players.PlayerAdded:Connect(function(player: Player): ()
	for _index: number, class: unknown in path.controller do
		task.spawn(function(): ()
			if class.PlayerAdded then
				class:PlayerAdded(player)
			end
		end)
	end

	for _index: number, class: unknown in tags do
		task.spawn(function(): ()
			if class.PlayerAdded then
				class:PlayerAdded(player)
			end
		end)
	end

	player.CharacterAdded:Connect(function(character: Model): ()
		for _index: number, class: unknown in path.controller do
			task.spawn(function(): ()
				if class.AnyCharacterAdded then
					class:AnyCharacterAdded(player, character)
				end
			end)
		end

		for _index: number, class: unknown in tags do
			task.spawn(function(): ()
				if class.AnyCharacterAdded then
					class:AnyCharacterAdded(player, character)
				end
			end)
		end

		local humanoid: Humanoid = character:WaitForChild("Humanoid")

		humanoid.Died:Connect(function(): ()
			for _index: number, class: unknown in path.controller do
				if class.AnyDied then
					class:AnyDied(player, character)
				end
			end

			for _index: number, class: unknown in tags do
				task.spawn(function(): ()
					if class.AnyDied then
						class:AnyDied(player, character)
					end
				end)
			end
		end)
	end)

	player.CharacterAppearanceLoaded:Connect(function(character: Model): ()
		for _index: number, class: unknown in path.controller do
			task.spawn(function(): ()
				if class.AnyCharacterAppearanceLoaded then
					class:AnyCharacterAppearanceLoaded(player, character)
				end
			end)
		end

		for _index: number, class: unknown in tags do
			task.spawn(function(): ()
				if class.AnyCharacterAppearanceLoaded then
					class:AnyCharacterAppearanceLoaded(player, character)
				end
			end)
		end
	end)
end)

Players.LocalPlayer.CharacterAdded:Connect(function(character: Model): ()
	for _index: number, class: unknown in path.controller do
		task.spawn(function(): ()
			if class.CharacterAdded then
				class:CharacterAdded(character)
			end
		end)
	end

	for _index: number, class: unknown in tags do
		task.spawn(function(): ()
			if class.CharacterAdded then
				class:CharacterAdded(character)
			end
		end)
	end

	local humanoid: Humanoid = character:WaitForChild("Humanoid")

	humanoid.Died:Connect(function(): ()
		for _index: number, class: unknown in path.controller do
			task.spawn(function(): ()
				if class.Died then
					class:Died(character)
				end
			end)
		end

		for _index: number, class: unknown in tags do
			task.spawn(function(): ()
				if class.Died then
					class:Died(character)
				end
			end)
		end
	end)
end)

Players.LocalPlayer.CharacterAppearanceLoaded:Connect(function(character: Model): ()
	for _index: number, class: unknown in path.controller do
		task.spawn(function(): ()
			if class.CharacterAdded then
				class:CharacterAppearanceLoaded(character)
			end
		end)
	end

	for _index: number, class: unknown in tags do
		task.spawn(function(): ()
			if class.CharacterAdded then
				class:CharacterAppearanceLoaded(character)
			end
		end)
	end
end)

RunService.Heartbeat:Connect(function(delta: number): ()
	for _index: number, class: unknown in path.controller do
		task.defer(function(): ()
			if class.Physics then
				class:Physics(delta)
			end
		end)
	end

	for _index: number, class: unknown in tags do
		task.defer(function(): ()
			if class.Physics then
				class:Physics(delta)
			end
		end)
	end
end)

RunService.PreSimulation:Connect(function(delta: number): ()
	for _index: number, class: unknown in path.controller do
		task.defer(function(): ()
			if class.Stepped then
				class:Stepped(delta)
			end
		end)
	end

	for _index: number, class: unknown in tags do
		task.defer(function(): ()
			if class.Stepped then
				class:Stepped(delta)
			end
		end)
	end
end)

RunService.PreRender:Connect(function(delta: number): ()
	for _index: number, class: unknown in path.controller do
		task.defer(function(): ()
			if class.Render then
				class:Render(delta)
			end
		end)
	end

	for _index: number, class: unknown in tags do
		task.defer(function(): ()
			if class.Render then
				class:Render(delta)
			end
		end)
	end
end)

for _index: number, ui: ScreenGui in Players.LocalPlayer.PlayerGui:GetChildren() do
	if ui:IsA("ScreenGui") and not ui:GetAttribute("SkipResetOnSpawn") then
		ui.ResetOnSpawn = false
	end
end

Players.LocalPlayer.PlayerGui.ChildAdded:Connect(function(ui: Instance): ()
	if ui:IsA("ScreenGui") and not ui:GetAttribute("SkipResetOnSpawn") then
		ui.ResetOnSpawn = false
	end
end)
