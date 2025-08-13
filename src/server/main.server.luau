--!nocheck
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.util.Logger)
local ServerInitConfig = require(ServerScriptService.server.serverConfig.ServerInitConfig)

local path = {}
path.controller = {}
path.module = {}
path.tag = {}
local loadFirst = {}
local load = {}
local tags = {}

for _index: number, folder: Folder in script.Parent:GetChildren() do
	if table.find(ServerInitConfig, folder.Name) then
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
			tags[module.Name] = required
		else
			path[moduleType][module.Name] = required
		end
	end
end

local function InitController(required: unknown): ()
	required.path = path

	local Init: ((unknown?) -> unknown?)? = required.Init
	local PlayerAdded: ((unknown?, Player) -> unknown?)? = required.PlayerAdded

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

	if PlayerAdded then
		for _index: number, player: Player in Players:GetPlayers() do
			PlayerAdded(required, player)
		end
	end
end

local function InitTag(required: unknown): ()
	local tag: string = required.tag
	if not tag then
		return
	end

	local new: ((Instance) -> unknown)? = required.new
	if not new then
		return
	end

	local PlayerAdded: ((unknown, Player) -> unknown)? = required.PlayerAdded

	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance: Instance): ()
		local class: unknown = new(instance, path)

		if class then
			class.path = path
			path.tag[instance] = class

			if PlayerAdded then
				for _index: number, player: Player in Players:GetPlayers() do
					task.spawn(function(): ()
						PlayerAdded(required, player)
					end)
				end
			end
		end
	end)

	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance: Instance): ()
		if path.tag[instance] and path.tag[instance].Destroy then
			path.tag[instance]:Destroy(instance)
			path.tag[instance] = nil
		end
	end)

	for _index: number, instance: Instance in CollectionService:GetTagged(tag) do
		task.spawn(function(): ()
			local class: unknown = new(instance, path)

			if class then
				class.path = path
				path.tag[instance] = class

				if PlayerAdded then
					for _index: number, player: Player in Players:GetPlayers() do
						task.spawn(function(): ()
							PlayerAdded(required, player)
						end)
					end
				end
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

for _index: number, required: unknown in tags do
	task.spawn(InitTag, required)
end

Players.PlayerAdded:Connect(function(player: Player): ()
	for _index: number, class: unknown in path.controller do
		task.spawn(function(): ()
			if class.PlayerAdded then
				class:PlayerAdded(player)
			end
		end)
	end

	for _index: number, class: unknown in path.tag do
		task.spawn(function(): ()
			if class.PlayerAdded then
				class:PlayerAdded(player)
			end
		end)
	end

	player.CharacterAdded:Connect(function(character: Model): ()
		for _index: number, class: unknown in path.controller do
			task.spawn(function(): ()
				if class.CharacterAdded then
					class:CharacterAdded(player, character)
				end
			end)
		end

		for _index: number, class: unknown in path.tag do
			task.spawn(function(): ()
				if class.CharacterAdded then
					class:CharacterAdded(player, character)
				end
			end)
		end

		local humanoid: Humanoid = character:WaitForChild("Humanoid")

		humanoid.Died:Connect(function(): ()
			for _index: number, class: unknown in path.controller do
				task.spawn(function(): ()
					if class.Died then
						class:Died(player, character)
					end
				end)
			end

			for _index: number, class: unknown in path.tag do
				task.spawn(function(): ()
					if class.Died then
						class:Died(player, character)
					end
				end)
			end
		end)
	end)

	player.CharacterAppearanceLoaded:Connect(function(character: Model): ()
		for _index: number, class: unknown in path.controller do
			task.spawn(function(): ()
				if class.CharacterAppearanceLoaded then
					class:CharacterAppearanceLoaded(player, character)
				end
			end)
		end

		for _index: number, class: unknown in path.tag do
			task.spawn(function(): ()
				if class.CharacterAppearanceLoaded then
					class:CharacterAppearanceLoaded(player, character)
				end
			end)
		end
	end)
end)

RunService.Heartbeat:Connect(function(delta: number): ()
	for _index: number, class: unknown in path.controller do
		task.defer(function(): ()
			if class.Physics then
				class:Physics(delta)
			end
		end)
	end

	for _index: number, class: unknown in path.tag do
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

	for _index: number, class: unknown in path.tag do
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

	for _index: number, class: unknown in path.tag do
		task.defer(function(): ()
			if class.Render then
				class:Render(delta)
			end
		end)
	end
end)
