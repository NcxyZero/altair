--!nocheck
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local GetBridge = require(ReplicatedStorage.util.GetBridge)
local Logger = require(ReplicatedStorage.util.Logger)
local ServerInitConfig = require(ServerScriptService.server.serverConfig.ServerInitConfig)

local replicateToServer = Instance.new("RemoteFunction")
replicateToServer.Name = "_GetBridgeFunction"
replicateToServer.Parent = ReplicatedStorage

replicateToServer.OnServerInvoke = function(_player: Player, name: string): ()
	GetBridge(name) -- error handling for client if server doesn't have bridge
end

local path = {}
path.controller = {}
path.module = {}
path.tag = {}
path.other = {}

local loadFirst = {}
local load = {}
local tagModules = {}
local tagInstances = {}

local folders: { Folder } = script.Parent:GetChildren()
table.insert(folders, ReplicatedStorage.shared.modules)

for _index: number, folder: Folder in folders do
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

		local moduleName: string = module.Name
		if moduleName:lower():find("template") then
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
			tagModules[module.Name] = required
		else
			path[moduleType][module.Name] = required
		end

		if moduleType == "other" then
			required.path = path
		elseif required.type then
			required.name = moduleName
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
		Logger.warn("Tag not specified for required module:", required.name)
		return
	end

	local new: ((Instance) -> unknown)? = required.new
	if not new then
		Logger.warn("New function not specified for tag module:", required.name)
		return
	end

	local PlayerAdded: ((unknown, Player) -> unknown)? = required.PlayerAdded

	required.tagclasses = {}

	local function addInstance(instance: Instance): ()
		local class: unknown = new(instance, path)
		if not class then
			return
		end

		class.path = path

		if not tagInstances[instance] then
			tagInstances[instance] = {}
		end
		tagInstances[instance][tag] = class

		if not path.tag[instance] then
			path.tag[instance] = {}
		end
		path.tag[instance][tag] = class

		if not required.tagclass then
			required.tagclass = class
		end

		table.insert(required.tagclasses, class)

		if PlayerAdded then
			for _index: number, player: Player in Players:GetPlayers() do
				task.spawn(PlayerAdded, required, player)
			end
		end
	end

	local function removeInstance(instance: Instance): ()
		local class: unknown = tagInstances[instance] and tagInstances[instance][tag]

		table.remove(required.tagclasses, table.find(required.tagclasses, class))

		if required.tagclass == class then
			required.tagclass = select(2, next(required.tagclasses))
		end

		if class and class.Destroy then
			class:Destroy(instance)
			class = nil
		end

		if path.tag[instance] then
			path.tag[instance][tag] = nil
		end
	end

	CollectionService:GetInstanceAddedSignal(tag):Connect(addInstance)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(removeInstance)

	for _index: number, instance: Instance in CollectionService:GetTagged(tag) do
		task.spawn(addInstance, instance)
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
		Logger.warn(`Failed to initialize controller of type {required.type or "unknown"}: {err}`)
	end
end

for _index: number, required: unknown in tagModules do
	task.spawn(InitTag, required)
end

for _index: number, required: unknown in loadFirst do
	local success: boolean, err: unknown = xpcall(function(): ()
		StartController(required)
	end, function(err2: string): string
		return debug.traceback(err2)
	end)

	if not success then
		Logger.warn(`Failed to start priority controller of type {required.type or "unknown"}: {err}`)
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

Players.PlayerRemoving:Connect(function(player: Player): ()
	for _index: number, class: unknown in path.controller do
		task.spawn(function(): ()
			if class.PlayerRemoving then
				class:PlayerRemoving(player)
			end
		end)
	end

	for _instance: Instance, classes: { unknown } in path.tag do
		for _index: number, class: unknown in classes do
			task.spawn(function(): ()
				if class.PlayerRemoving then
					class:PlayerRemoving(player)
				end
			end)
		end
	end
end)

Players.PlayerAdded:Connect(function(player: Player): ()
	for _index: number, class: unknown in path.controller do
		task.spawn(function(): ()
			if class.PlayerAdded then
				class:PlayerAdded(player)
			end
		end)
	end

	for _instance: Instance, classes: { unknown } in path.tag do
		for _index: number, class: unknown in classes do
			task.spawn(function(): ()
				if class.PlayerAdded then
					class:PlayerAdded(player)
				end
			end)
		end
	end

	player.CharacterAdded:Connect(function(character: Model): ()
		for _index: number, class: unknown in path.controller do
			task.spawn(function(): ()
				if class.CharacterAdded then
					class:CharacterAdded(player, character)
				end
			end)
		end

		for _instance: Instance, classes: { unknown } in path.tag do
			for _index: number, class: unknown in classes do
				task.defer(function(): ()
					if class.CharacterAdded then
						class:CharacterAdded(player, character)
					end
				end)
			end
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

			for _instance: Instance, classes: { unknown } in path.tag do
				for _index: number, class: unknown in classes do
					task.defer(function(): ()
						if class.Died then
							class:Died(player, character)
						end
					end)
				end
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

		for _instance: Instance, classes: { unknown } in path.tag do
			for _index: number, class: unknown in classes do
				task.defer(function(): ()
					if class.CharacterAppearanceLoaded then
						class:CharacterAppearanceLoaded(player, character)
					end
				end)
			end
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

	for _instance: Instance, classes: { unknown } in path.tag do
		for _index: number, class: unknown in classes do
			task.defer(function(): ()
				if class.Physics then
					class:Physics(delta)
				end
			end)
		end
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

	for _instance: Instance, classes: { unknown } in path.tag do
		for _index: number, class: unknown in classes do
			task.defer(function(): ()
				if class.Stepped then
					class:Stepped(delta)
				end
			end)
		end
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

	for _instance: Instance, classes: { unknown } in path.tag do
		for _index: number, class: unknown in classes do
			task.defer(function(): ()
				if class.Render then
					class:Render(delta)
				end
			end)
		end
	end
end)
