--!nocheck
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local ClientInitConfig = require(StarterPlayer.StarterPlayerScripts.clientConfig.ClientInitConfig)

local path = {}
path.controller = {}
path.module = {}
path.local_tag = {}
path.tag = {}
local loadFirst = {}
local load = {}

for _, folder in script.Parent:GetChildren() do
	if table.find(ClientInitConfig, folder.Name) then
		continue
	end

	for _index: number, module: Instance in folder:GetDescendants() do
		if not module:IsA("ModuleScript") then
			continue
		end

		if module.Name:lower():find("template") then
			continue
		end

		pcall(function(): ()
			local required: unknown = require(module)
			local moduleType: string = required.type or "module"
			path[moduleType][module.Name] = required

			if moduleType == "controller" then
				if required.index then
					loadFirst[required.index] = required
				else
					table.insert(load, required)
				end
			end
		end)
	end
end

local function InitController(required: unknown): ()
	required.path = path

	local Init: ((unknown?) -> unknown?)? = required.Init
	if Init then
		Init(required)
	end
end

local tags = {}

local function InitTag(required: unknown): ()
	local tag: string = required.tag
	if not tag then
		return
	end

	local new: ((Instance) -> unknown)? = required.new
	if not new then
		return
	end

	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance: Instance): ()
		local class: unknown = new(instance)
		tags[instance] = class
	end)

	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance: Instance): ()
		if tags[instance] and tags[instance].Destroy then
			tags[instance]:Destroy(instance)
			tags[instance] = nil
		end
	end)

	for _index: number, instance: Instance in CollectionService:GetTagged(tag) do
		local class: unknown = new(instance)
		tags[instance] = class
	end
end

local function InitLocalTag(required: unknown): ()
	local tag: string = required.tag
	if not tag then
		return
	end

	local new: ((Instance) -> unknown)? = required.new
	if not new then
		return
	end

	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance: Instance): ()
		if not Players.LocalPlayer:IsAncestorOf(instance) then
			if not Players.LocalPlayer.Character or not Players.LocalPlayer.Character:IsAncestorOf(instance) then
				return
			end
		end

		local class: unknown = new(instance)
		tags[instance] = class
	end)

	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance: Instance): ()
		if tags[instance] and tags[instance].Destroy then
			tags[instance]:Destroy(instance)
			tags[instance] = nil
		end
	end)

	for _index: number, instance: Instance in CollectionService:GetTagged(tag) do
		if not Players.LocalPlayer:IsAncestorOf(instance) then
			if not Players.LocalPlayer.Character or not Players.LocalPlayer.Character:IsAncestorOf(instance) then
				continue
			end
		end

		local class: unknown = new(instance)
		tags[instance] = class
	end
end

for _index: number, required: unknown in loadFirst do
	InitController(required)
end

for _index: number, required: unknown in load do
	InitController(required)
end

for _index: number, required: unknown in path.tag do
	task.spawn(InitTag, required)
end

for _index: number, required: unknown in path.local_tag do
	task.spawn(InitLocalTag, required)
end

Players.PlayerAdded:Connect(function(player: Player): ()
	for _index: number, class: unknown in path.controller do
		if class.PlayerAdded then
			class:PlayerAdded(player)
		end
	end

	for _index: number, class: unknown in tags do
		if class.PlayerAdded then
			class:PlayerAdded(player)
		end
	end

	player.CharacterAdded:Connect(function(character: Model): ()
		for _index: number, class: unknown in path.controller do
			if class.AnyCharacterAdded then
				class:AnyCharacterAdded(player, character)
			end
		end

		for _index: number, class: unknown in tags do
			if class.AnyCharacterAdded then
				class:AnyCharacterAdded(player, character)
			end
		end

		local humanoid: Humanoid = character:WaitForChild("Humanoid")

		humanoid.Died:Connect(function(): ()
			for _index: number, class: unknown in path.controller do
				if class.AnyDied then
					class:AnyDied(player, character)
				end
			end

			for _index: number, class: unknown in tags do
				if class.AnyDied then
					class:AnyDied(player, character)
				end
			end
		end)
	end)

	player.CharacterAppearanceLoaded:Connect(function(character: Model): ()
		for _index: number, class: unknown in path.controller do
			if class.AnyCharacterAppearanceLoaded then
				class:AnyCharacterAppearanceLoaded(player, character)
			end
		end

		for _index: number, class: unknown in tags do
			if class.AnyCharacterAppearanceLoaded then
				class:AnyCharacterAppearanceLoaded(player, character)
			end
		end
	end)
end)

Players.LocalPlayer.CharacterAdded:Connect(function(character: Model): ()
	for _index: number, class: unknown in path.controller do
		if class.CharacterAdded then
			class:CharacterAdded(character)
		end
	end

	for _index: number, class: unknown in tags do
		if class.CharacterAdded then
			class:CharacterAdded(character)
		end
	end

	local humanoid: Humanoid = character:WaitForChild("Humanoid")

	humanoid.Died:Connect(function(): ()
		for _index: number, class: unknown in path.controller do
			if class.Died then
				class:Died(character)
			end
		end

		for _index: number, class: unknown in tags do
			if class.Died then
				class:Died(character)
			end
		end
	end)
end)

Players.LocalPlayer.CharacterAppearanceLoaded:Connect(function(character: Model): ()
	for _index: number, class: unknown in path.controller do
		if class.CharacterAdded then
			class:CharacterAppearanceLoaded(character)
		end
	end

	for _index: number, class: unknown in tags do
		if class.CharacterAdded then
			class:CharacterAppearanceLoaded(character)
		end
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
