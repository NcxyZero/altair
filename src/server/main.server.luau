--!nocheck
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Bifrost = require(ReplicatedStorage.package.Bifrost)
local GetBridge = require(ReplicatedStorage.util.Core.GetBridge)
local GetFunctionBridge = require(ReplicatedStorage.util.Core.GetFunctionBridge)
local Logger = require(ReplicatedStorage.util.Core.Logger)
local Maid = require(ReplicatedStorage.package.Maid)
local Promise = require(ReplicatedStorage.package.Promise)
local ServerInitConfig = require(ServerScriptService.server.serverConfig.ServerInitConfig)

type BridgeRequestWindow = {
	count: number,
	windowStart: number,
}

local BRIDGE_NAME_MAX_LENGTH: number = 100 -- longest bridge name a client may ask about; Bridgenet2 names are attribute names, which Roblox caps at 100 characters
local BRIDGE_REQUEST_LIMIT: number = 200 -- bridge requests one player may send per window; a client asks once per bridge name it uses
local BRIDGE_REQUEST_WINDOW: number = 10 -- seconds of one bridge request window
local BRIDGE_STARTUP_POLL_INTERVAL: number = 0.1 -- seconds between checks while a bridge request waits for startup
local BRIDGE_STARTUP_WAIT_LIMIT: number = 30 -- longest wait, in seconds, of a bridge request for a bridge that startup has not created yet

-- bridges of client halves Altair ships without a server module (CharacterScaleController, TeleportToBaseButton,
-- TeleportToTagButton); created here so clients get them confirmed at join, while a game that uses them listens itself
local CLIENT_ONLY_BRIDGE_NAMES: { string } = { "CharacterScale", "TeleportToBase", "TeleportToTag" }

local startupFinished: boolean = false -- true once every controller has been initialized and started; bridge requests stop waiting then

local bridgeRequests: { [Player]: BridgeRequestWindow } = {} -- each player's bridge requests in the current window
local controllerPlayers: { [unknown]: { [Player]: boolean } } = {} -- players each initialized controller has received, so it gets PlayerAdded once per player
local playerMaids: { [Player]: Maid.Maid } = {} -- players added and not removed yet, with their character event connections

local replicateToServer = Instance.new("RemoteFunction")
replicateToServer.Name = "_GetBridgeFunction"
replicateToServer.Parent = ReplicatedStorage

local replicateToServerFunction = Bifrost.FunctionBridge("_REPLICATE_BRIDGE_FUNCTION")

-- Counts the request in the player's window and checks the name; anything else a client sends is refused.
local function acceptBridgeRequest(player: Player, name: unknown): boolean
	if player.Parent ~= Players then
		return false
	end

	local currentTime: number = os.clock()
	local requests: BridgeRequestWindow = bridgeRequests[player]
	if not requests or currentTime - requests.windowStart >= BRIDGE_REQUEST_WINDOW then
		local newRequests: BridgeRequestWindow = {
			count = 0,
			windowStart = currentTime,
		}
		bridgeRequests[player] = newRequests

		requests = newRequests
	end

	requests.count += 1

	return requests.count <= BRIDGE_REQUEST_LIMIT
		and type(name) == "string"
		and #name > 0
		and #name <= BRIDGE_NAME_MAX_LENGTH
end

-- True once the server itself has created the bridge. A client may ask before startup creates it, so the request
-- waits until startup finishes; the server never creates a bridge because a client asked for it.
local function waitForServerBridge(name: string, getExisting: (name: string, existingOnly: boolean) -> unknown): boolean
	local deadline: number = os.clock() + BRIDGE_STARTUP_WAIT_LIMIT
	while not getExisting(name, true) do
		if startupFinished or os.clock() >= deadline then
			return false
		end

		task.wait(BRIDGE_STARTUP_POLL_INTERVAL)
	end

	return true
end

replicateToServerFunction:OnInvoke(function(player: Player, name: unknown): boolean
	return acceptBridgeRequest(player, name) and waitForServerBridge(name, GetFunctionBridge)
end)

replicateToServer.OnServerInvoke = function(player: Player, name: unknown): boolean
	return acceptBridgeRequest(player, name) and waitForServerBridge(name, GetBridge)
end

for _index: number, bridgeName: string in CLIENT_ONLY_BRIDGE_NAMES do
	GetBridge(bridgeName)
end

local path = {}
path.controller = {}
path.module = {}
path.tag = {}
path.other = {}

local loadFirst = {}
local loadFirstEntries = {}
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
		if table.find(ServerInitConfig, moduleName) then
			continue
		end

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

		if type(required) ~= "table" then
			continue
		end

		local moduleType: string = required.type or "module"

		if moduleType == "controller" then
			local rawIndex: unknown = required.index
			if type(rawIndex) == "number" then
				table.insert(loadFirstEntries, {
					index = rawIndex,
					moduleName = moduleName,
					required = required,
				})
			else
				table.insert(load, required)
			end
		end

		if moduleType == "tag" then
			tagModules[moduleName] = required
		else
			path[moduleType][moduleName] = required
		end

		if moduleType == "other" then
			required.path = path
		elseif required.type then
			required.name = moduleName
		end
	end
end

table.sort(loadFirstEntries, function(a: any, b: any): boolean
	if a.index == b.index then
		return tostring(a.moduleName) < tostring(b.moduleName)
	end

	return a.index < b.index
end)

for index: number = 1, #loadFirstEntries do
	local entry: any = loadFirstEntries[index]
	local required: unknown = entry.required

	table.insert(loadFirst, required)
end

-- True while the controller has received PlayerAdded for the player and PlayerRemoving has not run for it yet.
local function controllerHasPlayer(class: unknown, player: Player): boolean
	local players: { [Player]: boolean }? = controllerPlayers[class]

	return players ~= nil and players[player] == true
end

-- Gives an added player to an initialized controller once. Whichever comes later, the controller's Init or the
-- player's join, spawns the controller's PlayerAdded, so players joining while startup runs are not missed.
local function addControllerPlayer(class: unknown, player: Player): ()
	local players: { [Player]: boolean } = controllerPlayers[class]
	if not players or players[player] or not playerMaids[player] then
		return
	end

	players[player] = true

	if class.PlayerAdded then
		task.spawn(class.PlayerAdded, class, player)
	end
end

-- Calls a character lifecycle method on every controller that has the player and on every tag class.
local function dispatchCharacterEvent(methodName: string, player: Player, character: Model): ()
	for _name: string, class: unknown in path.controller do
		if not class[methodName] or not controllerHasPlayer(class, player) then
			continue
		end

		task.spawn(class[methodName], class, player, character)
	end

	for _instance: Instance, classes: { [string]: unknown } in path.tag do
		for _tag: string, class: unknown in classes do
			task.defer(function(): ()
				if class[methodName] then
					class[methodName](class, player, character)
				end
			end)
		end
	end
end

-- Adds a player once, whether the player was already in the game when the bootstrap started or joined later:
-- connects the character events and gives the player to every initialized controller and every tag class.
local function onPlayerAdded(player: Player): ()
	if playerMaids[player] or player.Parent ~= Players then
		return
	end

	local maid: Maid.Maid = Maid.new()
	playerMaids[player] = maid

	maid:GiveTask(player.CharacterAdded:Connect(function(character: Model): ()
		dispatchCharacterEvent("CharacterAdded", player, character)

		local humanoid: Humanoid = character:WaitForChild("Humanoid")

		if playerMaids[player] ~= maid then
			return
		end

		maid.Died = humanoid.Died:Connect(function(): ()
			dispatchCharacterEvent("Died", player, character)
		end)
	end))
	maid:GiveTask(player.CharacterAppearanceLoaded:Connect(function(character: Model): ()
		dispatchCharacterEvent("CharacterAppearanceLoaded", player, character)
	end))

	for _name: string, class: unknown in path.controller do
		addControllerPlayer(class, player)
	end

	for _instance: Instance, classes: { [string]: unknown } in path.tag do
		for _tag: string, class: unknown in classes do
			task.spawn(function(): ()
				if class.PlayerAdded then
					class:PlayerAdded(player)
				end
			end)
		end
	end
end

-- Calls PlayerRemoving on the controllers that received the player, and on every other module and tag class.
local function onPlayerRemoving(player: Player): ()
	local maid: Maid.Maid? = playerMaids[player]
	if maid then
		maid:DoCleaning()
	end

	bridgeRequests[player] = nil
	playerMaids[player] = nil

	for _name: string, class: unknown in path.controller do
		local players: { [Player]: boolean } = controllerPlayers[class]
		if not players or not players[player] then
			continue
		end

		players[player] = nil

		if class.PlayerRemoving then
			task.spawn(class.PlayerRemoving, class, player)
		end
	end

	for _name: string, class: unknown in path.other do
		task.spawn(function(): ()
			if class.PlayerRemoving then
				class:PlayerRemoving(player)
			end
		end)
	end

	for _instance: Instance, classes: { [string]: unknown } in path.tag do
		for _tag: string, class: unknown in classes do
			task.spawn(function(): ()
				if class.PlayerRemoving then
					class:PlayerRemoving(player)
				end
			end)
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

	-- players who joined before this Init finished; later joins reach the controller through onPlayerAdded
	controllerPlayers[required] = {}

	for _index: number, player: Player in Players:GetPlayers() do
		addControllerPlayer(required, player)
	end
end

local function InitControllerAsync(required: unknown, context: string): Promise.Promise
	local delay: number = 5
	return Promise.race({
		Promise.delay(delay):andThen(function(): ()
			Logger.warn(
				`Initialization of {context} controller {required.type or "unknown"} ({required.name or "unknown"}) exceeded {delay}s, continuing to next`
			)
		end),
		Promise.new(function(resolve: () -> ()): ()
			task.spawn(function(): ()
				InitController(required)

				resolve()
			end)
		end),
	})
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
		local classIndex: number? = class and table.find(required.tagclasses, class) or nil

		if classIndex then
			table.remove(required.tagclasses, classIndex)
		end

		if required.tagclass == class then
			required.tagclass = select(2, next(required.tagclasses))
		end

		if class and class.Destroy then
			class:Destroy(instance)
			class = nil
		end

		if path.tag[instance] then
			path.tag[instance][tag] = nil
			if not next(path.tag[instance]) then
				path.tag[instance] = nil
			end
		end

		if tagInstances[instance] then
			tagInstances[instance][tag] = nil
			if not next(tagInstances[instance]) then
				tagInstances[instance] = nil
			end
		end
	end

	CollectionService:GetInstanceAddedSignal(tag):Connect(addInstance)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(removeInstance)

	for _index: number, instance: Instance in CollectionService:GetTagged(tag) do
		task.spawn(addInstance, instance)
	end
end

-- Connected before the first Init, then the players already in the game are added, so nobody slips between them.
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _index: number, player: Player in Players:GetPlayers() do
	onPlayerAdded(player)
end

for index: number = 1, #loadFirst do
	local required: unknown = loadFirst[index]
	local success: boolean, err: unknown = xpcall(function(): ()
		InitControllerAsync(required, "priority"):expect()
	end, function(err2: string): string
		return debug.traceback(err2)
	end)

	if not success then
		Logger.warn(`Failed to initialize priority controller {required.type or "unknown"}: {err}`)
	end
end

for _index: number, required: unknown in load do
	local success: boolean, err: unknown = xpcall(function(): ()
		InitControllerAsync(required, "regular"):expect()
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

for index: number = 1, #loadFirst do
	local required: unknown = loadFirst[index]
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

startupFinished = true

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
