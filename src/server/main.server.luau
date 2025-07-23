--!nocheck
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local modules = (script.Parent :: Folder):WaitForChild("modules")

local path = {}
path.controller = {}
path.module = {}
path.tag = {}
local loadFirst = {}
local load = {}

for _index: number, module: Instance in modules:GetChildren() do
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

		path[moduleType][module.Name] = path[moduleType][module.Name] :: required.Default
	end)
end

local function InitController(required: unknown): ()
	required.path = path

	local Init: ((unknown?) -> unknown?)? = required.Init
	local PlayerAdded: ((unknown?, Player) -> unknown?)? = required.PlayerAdded

	if Init then
		Init(required)
	end

	if PlayerAdded then
		for _index: number, player: Player in Players:GetPlayers() do
			PlayerAdded(required, player)
		end
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

	local PlayerAdded: ((unknown, Player) -> unknown)? = required.PlayerAdded

	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance: Instance): ()
		local class: unknown = new(instance)
		tags[instance] = class

		if PlayerAdded then
			for _index: number, player: Player in Players:GetPlayers() do
				PlayerAdded(required, player)
			end
		end
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

		if PlayerAdded then
			for _index: number, player: Player in Players:GetPlayers() do
				PlayerAdded(required, player)
			end
		end
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
			if class.CharacterAdded then
				class:CharacterAdded(player, character)
			end
		end

		for _index: number, class: unknown in tags do
			if class.CharacterAdded then
				class:CharacterAdded(player, character)
			end
		end

		local humanoid: Humanoid = character:WaitForChild("Humanoid")

		humanoid.Died:Connect(function(): ()
			for _index: number, class: unknown in path.controller do
				if class.Died then
					class:Died(player, character)
				end
			end

			for _index: number, class: unknown in tags do
				if class.Died then
					class:Died(player, character)
				end
			end
		end)
	end)

	player.CharacterAppearanceLoaded:Connect(function(character: Model): ()
		for _index: number, class: unknown in path.controller do
			if class.CharacterAppearanceLoaded then
				class:CharacterAppearanceLoaded(player, character)
			end
		end

		for _index: number, class: unknown in tags do
			if class.CharacterAppearanceLoaded then
				class:CharacterAppearanceLoaded(player, character)
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
