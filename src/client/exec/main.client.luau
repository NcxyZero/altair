--!nocheck
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClientInitConfig = require(ReplicatedStorage.client.clientConfig.ClientInitConfig)
local LocalPlayer = require(ReplicatedStorage.util.LocalPlayer)
local Logger = require(ReplicatedStorage.util.Logger)
local Maid = require(ReplicatedStorage.package.Maid)
local OpenGui = require(ReplicatedStorage.util.OpenGui)

local path = {}
path.controller = {}
path.module = {}
path.local_tag = {}
path.tag = {}
path.other = {}

local moduleTags = {}
local moduleTagsLocal = {}
local tagInstances = {}
local loadFirst = {}
local load = {}

local folders: { Folder } = ReplicatedStorage:WaitForChild("client"):GetChildren()
table.insert(folders, ReplicatedStorage.shared.modules)

for _index: number, folder: Folder in folders do
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
			moduleTags[module.Name] = required
		elseif moduleType == "local_tag" then
			moduleTagsLocal[module.Name] = required
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
		Logger.warn("Tag not specified for required module")
		return
	end

	local new: ((Instance) -> unknown)? = required.new
	if not new then
		Logger.warn("New function not specified for tag module:", required.name)
		return
	end

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

		path.tag[instance] = class

		if not required.tagclass then
			required.tagclass = class
		end

		table.insert(required.tagclasses, class)
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

		path.tag[instance] = nil
	end

	CollectionService:GetInstanceAddedSignal(tag):Connect(addInstance)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(removeInstance)

	for _index: number, instance: Instance in CollectionService:GetTagged(tag) do
		task.spawn(addInstance, instance)
	end
end

local function InitLocalTag(required: unknown): ()
	local tag: string = required.tag
	if not tag then
		Logger.warn("Tag not specified for local tag module:", required.name)
		return
	end

	local new: ((Instance) -> unknown)? = required.new
	if not new then
		Logger.warn("New function not specified for local tag module:", required.name)
		return
	end

	required.tagclasses = {}

	local function addInstance(instance: Instance): ()
		if not LocalPlayer:IsAncestorOf(instance) then
			if not LocalPlayer.Character or not LocalPlayer.Character:IsAncestorOf(instance) then
				return
			end
		end

		local class: unknown = new(instance, path)
		if not class then
			return
		end

		class.path = path

		if not tagInstances[instance] then
			tagInstances[instance] = {}
		end
		tagInstances[instance][tag] = class

		path.local_tag[instance] = class

		if not required.tagclass then
			required.tagclass = class
		end

		table.insert(required.tagclasses, class)

		if not class.closeButtons then
			return
		end

		if not class.closeButtonsMaid then
			class.closeButtonsMaid = Maid.new()
		end

		for _index: number, button: GuiButton in class.closeButtons do
			class.closeButtonsMaid:GiveTask(button.MouseButton1Down:Connect(function(): ()
				if class.Close then
					class:Close()
				else
					OpenGui:Close(required)
				end
			end))
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

		path.local_tag[instance] = nil
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
		Logger.warn(`Failed to initialize priority controller of type {required.type or "unknown"}: {err}`)
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

	for _index: number, class: unknown in path.tag do
		task.spawn(function(): ()
			if class.PlayerRemoving then
				class:PlayerRemoving(player)
			end
		end)
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

	for _index: number, class: unknown in path.tag do
		task.spawn(function(): ()
			if class.PlayerAdded then
				class:PlayerAdded(player)
			end
		end)
	end

	for _index: number, class: unknown in path.local_tag do
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

		for _index: number, class: unknown in path.tag do
			task.spawn(function(): ()
				if class.AnyCharacterAdded then
					class:AnyCharacterAdded(player, character)
				end
			end)
		end

		for _index: number, class: unknown in path.local_tag do
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

			for _index: number, class: unknown in path.tag do
				task.spawn(function(): ()
					if class.AnyDied then
						class:AnyDied(player, character)
					end
				end)
			end

			for _index: number, class: unknown in path.local_tag do
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

		for _index: number, class: unknown in path.tag do
			task.spawn(function(): ()
				if class.AnyCharacterAppearanceLoaded then
					class:AnyCharacterAppearanceLoaded(player, character)
				end
			end)
		end

		for _index: number, class: unknown in path.local_tag do
			task.spawn(function(): ()
				if class.AnyCharacterAppearanceLoaded then
					class:AnyCharacterAppearanceLoaded(player, character)
				end
			end)
		end
	end)
end)

LocalPlayer.CharacterAdded:Connect(function(character: Model): ()
	for _index: number, class: unknown in path.controller do
		task.spawn(function(): ()
			if class.CharacterAdded then
				class:CharacterAdded(character)
			end
		end)
	end

	for _index: number, class: unknown in path.tag do
		task.spawn(function(): ()
			if class.CharacterAdded then
				class:CharacterAdded(character)
			end
		end)
	end

	for _index: number, class: unknown in path.local_tag do
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

		for _index: number, class: unknown in path.tag do
			task.spawn(function(): ()
				if class.Died then
					class:Died(character)
				end
			end)
		end

		for _index: number, class: unknown in path.local_tag do
			task.spawn(function(): ()
				if class.Died then
					class:Died(character)
				end
			end)
		end
	end)
end)

LocalPlayer.CharacterAppearanceLoaded:Connect(function(character: Model): ()
	for _index: number, class: unknown in path.controller do
		task.spawn(function(): ()
			if class.CharacterAdded then
				class:CharacterAppearanceLoaded(character)
			end
		end)
	end

	for _index: number, class: unknown in path.tag do
		task.spawn(function(): ()
			if class.CharacterAdded then
				class:CharacterAppearanceLoaded(character)
			end
		end)
	end

	for _index: number, class: unknown in path.local_tag do
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

	for _index: number, class: unknown in path.tag do
		task.defer(function(): ()
			if class.Physics then
				class:Physics(delta)
			end
		end)
	end

	for _index: number, class: unknown in path.local_tag do
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

	for _index: number, class: unknown in path.local_tag do
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

	for _index: number, class: unknown in path.local_tag do
		task.defer(function(): ()
			if class.Render then
				class:Render(delta)
			end
		end)
	end
end)

for _index: number, ui: ScreenGui in LocalPlayer.PlayerGui:GetChildren() do
	if ui:IsA("ScreenGui") and not ui:GetAttribute("SkipResetOnSpawn") then
		ui.ResetOnSpawn = false
	end
end

LocalPlayer.PlayerGui.ChildAdded:Connect(function(ui: Instance): ()
	if ui:IsA("ScreenGui") and not ui:GetAttribute("SkipResetOnSpawn") then
		ui.ResetOnSpawn = false
	end
end)
