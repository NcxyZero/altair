local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileService = require(ReplicatedStorage.Packages.ProfileService)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Reflex = require(ReplicatedStorage.Packages.Reflex)
local Signal = require(ReplicatedStorage.Packages.Signal)

export type ServerPlayerProfile = {
	player: Player,
	profileStore: any,
	producer: any,
	nextActionIsReplicated: boolean,
}

export type Default = {
	index: number,
	type: string,
	gameData: {},
	profiles: { [Player]: ServerPlayerProfile? },
	playerDataLoadedEvent: Signal.Signal<Player, ServerPlayerProfile>,
	GetPlayerProfile: (self: Default, player: Player) -> ServerPlayerProfile?,
	WaitForPlayerProfile: (self: Default, player: Player) -> Promise.TypedPromise<ServerPlayerProfile>,
	PlayerAdded: (self: Default, player: Player) -> (),
	PlayerRemoving: (self: Default, player: Player) -> (),
	Init: (self: Default) -> (),
}

local ServerData: Default = {} :: Default
ServerData.index = 0
ServerData.type = "controller"
ServerData.profiles = {}
ServerData.gameData = {}
ServerData.playerDataLoadedEvent = Signal.new()

-- Default state for player profiles
local DEFAULT_PLAYER_STATE = {
	userId = 0,
	coins = 0,
	inventory = {},
	settings = {
		musicVolume = 0.5,
		sfxVolume = 0.5,
	},
}

-- Default state for game data
local DEFAULT_GAME_STATE = {
	serverStartTime = os.time(),
	activePlayers = 0,
}

-- Keys for datastore
local DATASTORE_KEY = "PlayerData_v1"
local function getPlayerKey(userId: number): string
	return "Player_" .. userId
end

-- Create remote events for communication
local ReplicateStore = Instance.new("RemoteEvent")
ReplicateStore.Name = "ReplicateStore"
ReplicateStore.Parent = ReplicatedStorage

local ReplicateGameStore = Instance.new("RemoteEvent")
ReplicateGameStore.Name = "ReplicateGameStore"
ReplicateGameStore.Parent = ReplicatedStorage

local GetPlayerData = Instance.new("RemoteFunction")
GetPlayerData.Name = "GetPlayerData"
GetPlayerData.Parent = ReplicatedStorage

local GetGameData = Instance.new("RemoteFunction")
GetGameData.Name = "GetGameData"
GetGameData.Parent = ReplicatedStorage

-- Save exceptions (fields that should not be saved to datastore)
local SAVE_EXCEPTIONS = {
	"userId",
	"currentInterior",
	"savedInteriorCFrame",
}

-- Create a producer for player data
local function CreatePlayerProducer(data: any)
	local producer = Reflex.createProducer(data, {
		setCoins = function(state, coins: number)
			state.coins = coins
			return state
		end,
		addCoins = function(state, amount: number)
			state.coins += amount
			return state
		end,
		setInventoryItem = function(state, itemId: string, amount: number)
			state.inventory[itemId] = amount
			return state
		end,
		removeInventoryItem = function(state, itemId: string)
			state.inventory[itemId] = nil
			return state
		end,
		setSetting = function(state, key: string, value: any)
			state.settings[key] = value
			return state
		end,
	})

	return producer
end

-- Create a producer for game data
local function CreateGameProducer(data: any)
	local producer = Reflex.createProducer(data, {
		setActivePlayers = function(state, count: number)
			state.activePlayers = count
			return state
		end,
		incrementActivePlayers = function(state)
			state.activePlayers += 1
			return state
		end,
		decrementActivePlayers = function(state)
			state.activePlayers = math.max(0, state.activePlayers - 1)
			return state
		end,
	})

	return producer
end

function ServerData:GetPlayerProfile(player: Player): ServerPlayerProfile?
	return self.profiles[player]
end

function ServerData:WaitForPlayerProfile(player: Player): Promise.TypedPromise<ServerPlayerProfile>
	return Promise.new(function(resolve, reject)
		local profile = self:GetPlayerProfile(player)
		local connection

		if profile then
			resolve(profile)
			return
		end

		connection = self.playerDataLoadedEvent:Connect(function(newPlayer, data)
			if newPlayer ~= player then
				return
			end

			connection:Disconnect()
			resolve(data)
		end)
	end)
end

function ServerData:PlayerAdded(player: Player): ()
	local ProfileStore = ProfileService.GetProfileStore(DATASTORE_KEY, DEFAULT_PLAYER_STATE)
	local profileStore = ProfileStore:LoadProfileAsync(getPlayerKey(player.UserId))

	if not profileStore then
		player:Kick("Failed to load your data. Please try again later.")
		return
	end

	profileStore:AddUserId(player.UserId) -- GDPR compliance
	profileStore:Reconcile() -- Fill in missing variables from ProfileTemplate

	profileStore:ListenToRelease(function()
		self.profiles[player] = nil
		-- The profile could've been loaded on another Roblox server:
		player:Kick("Your data has been loaded on another server.")
	end)

	if not player:IsDescendantOf(Players) then
		-- Player left before the profile loaded:
		profileStore:Release()
		return
	end

	local data = profileStore.Data
	data.userId = player.UserId

	local profile: ServerPlayerProfile = {
		player = player,
		profileStore = profileStore,
		producer = CreatePlayerProducer(data),
		nextActionIsReplicated = false,
	}

	local replicateMiddleware: Reflex.Middleware = function()
		return function(dispatch, name)
			return function(...)
				if profile.nextActionIsReplicated then
					profile.nextActionIsReplicated = false
					return dispatch(...)
				end

				ReplicateStore:FireClient(player, {
					name = name,
					arguments = { ... },
				})

				return dispatch(...)
			end
		end
	end

	profile.producer:applyMiddleware(replicateMiddleware)

	self.profiles[player] = profile
	self.playerDataLoadedEvent:Fire(player, profile)

	-- Update game data
	self.gameProducer:incrementActivePlayers()
end

function ServerData:PlayerRemoving(player: Player): ()
	local profile = self.profiles[player]
	if not profile then
		return
	end

	-- Save player data
	local baseStoreData = profile.producer:getState()
	local saveableData = {}

	for key, value in pairs(baseStoreData) do
		if table.find(SAVE_EXCEPTIONS, key) ~= nil then
			continue
		end

		saveableData[key] = value
	end

	profile.profileStore.Data = saveableData
	profile.profileStore:Release()
	self.profiles[player] = nil

	-- Update game data
	self.gameProducer:decrementActivePlayers()
end

function ServerData:Init(): ()
	-- Initialize game data
	self.gameProducer = CreateGameProducer(DEFAULT_GAME_STATE)

	local nextActionIsReplicated = false

	local replicateMiddleware: Reflex.Middleware = function()
		return function(dispatch, name)
			return function(...)
				if nextActionIsReplicated then
					nextActionIsReplicated = false
					return dispatch(...)
				end

				ReplicateGameStore:FireAllClients({
					name = name,
					arguments = { ... },
				})

				return dispatch(...)
			end
		end
	end

	self.gameProducer:applyMiddleware(replicateMiddleware)

	-- Set up remote events
	ReplicateStore.OnServerEvent:Connect(function(player, data: any)
		if type(data) ~= "table" then
			return
		end

		-- Secure actions are not allowed to be replicated
		local isSecureAction = data.name:find("^secure")
		if isSecureAction then
			warn("Player tried to replicate secure reflex action", data.name)
			return
		end

		local profile = self:GetPlayerProfile(player)
		if not profile then
			return
		end

		profile.nextActionIsReplicated = true
		profile.producer[data.name](unpack(data.arguments))
	end)

	ReplicateGameStore.OnServerEvent:Connect(function(player, data: any)
		if type(data) ~= "table" then
			return
		end

		-- Secure actions are not allowed to be replicated
		local isSecureAction = data.name:find("^secure")
		if isSecureAction then
			warn("Player tried to replicate secure reflex action", data.name)
			return
		end

		nextActionIsReplicated = true
		self.gameProducer[data.name](unpack(data.arguments))
	end)

	GetPlayerData.OnServerInvoke = function(player)
		local profile = self:GetPlayerProfile(player)
		if not profile then
			return nil
		end

		return profile.profileStore.Data
	end

	GetGameData.OnServerInvoke = function()
		return self.gameProducer:getState()
	end

	-- -- Initialize existing players
	-- for _, player in ipairs(Players:GetPlayers()) do
	-- 	task.spawn(function()
	-- 		self:PlayerAdded(player)
	-- 	end)
	-- end

	-- -- Connect player removing event
	-- Players.PlayerRemoving:Connect(function(player)
	-- 	self:PlayerRemoving(player)
	-- end)
end

return ServerData
