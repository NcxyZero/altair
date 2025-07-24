local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileService = require(ReplicatedStorage.package.ProfileService)
local Promise = require(ReplicatedStorage.package.Promise)
local Reflex = require(ReplicatedStorage.package.Reflex)
local Signal = require(ReplicatedStorage.package.Signal)

-- Import profile producers
local gameProfile = require(ReplicatedStorage.shared.reflex.gameProfile)
local inventoryProfile = require(ReplicatedStorage.shared.reflex.inventoryProfile)
local playerProfile = require(ReplicatedStorage.shared.reflex.playerProfile)
local settingsProfile = require(ReplicatedStorage.shared.reflex.settingsProfile)

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
	local ProfileStore = ProfileService.GetProfileStore(DATASTORE_KEY, playerProfile.DEFAULT_STATE)
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

	-- Create individual producers
	local playerProducer = playerProfile.CreateProducer(data)
	local settingsProducer = settingsProfile.CreateProducer(data.settings or settingsProfile.DEFAULT_STATE)
	local inventoryProducer = inventoryProfile.CreateProducer(data.inventory or inventoryProfile.DEFAULT_STATE)

	-- Combine producers
	local combinedProducer = Reflex.combineProducers({
		player = playerProducer,
		settings = settingsProducer,
		inventory = inventoryProducer,
	})

	local profile: ServerPlayerProfile = {
		player = player,
		profileStore = profileStore,
		producer = combinedProducer,
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
	local combinedState = profile.producer:getState()
	local saveableData = {}

	-- Extract data from combined state
	local playerState = combinedState.player
	local settingsState = combinedState.settings
	local inventoryState = combinedState.inventory

	-- Combine into a single state for saving
	for key, value in pairs(playerState) do
		if table.find(SAVE_EXCEPTIONS, key) ~= nil then
			continue
		end

		saveableData[key] = value
	end

	-- Add settings and inventory
	saveableData.settings = settingsState
	saveableData.inventory = inventoryState

	profile.profileStore.Data = saveableData
	profile.profileStore:Release()
	self.profiles[player] = nil

	-- Update game data
	self.gameProducer:decrementActivePlayers()
end

function ServerData:Init(): ()
	-- Initialize game data
	self.gameProducer = gameProfile.CreateProducer(gameProfile.DEFAULT_STATE)

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

		-- Return combined state for client
		local combinedState = profile.producer:getState()
		local clientData = {
			userId = combinedState.player.userId,
			coins = combinedState.player.coins,
			inventory = combinedState.inventory,
			settings = combinedState.settings,
		}

		return clientData
	end

	GetGameData.OnServerInvoke = function()
		return self.gameProducer:getState()
	end

	-- Initialize existing players
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:PlayerAdded(player)
		end)
	end

	-- Connect player removing event
	Players.PlayerRemoving:Connect(function(player)
		self:PlayerRemoving(player)
	end)
end

return ServerData
