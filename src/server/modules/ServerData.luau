local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gameProfile = require(ReplicatedStorage.shared.reflex.gameProfile)
local inventoryProfile = require(ReplicatedStorage.shared.reflex.inventoryProfile)
local playerProfile = require(ReplicatedStorage.shared.reflex.playerProfile)
local settingsProfile = require(ReplicatedStorage.shared.reflex.settingsProfile)

local IsValidUTF8 = require(ReplicatedStorage.util.IsValidUTF8)
local ProfileService = require(ReplicatedStorage.package.ProfileService)
local Promise = require(ReplicatedStorage.package.Promise)
local Reflex = require(ReplicatedStorage.package.Reflex)
local Signal = require(ReplicatedStorage.package.Signal)

export type Data = {
	game: gameProfile.State,
	inventory: inventoryProfile.State,
	player: playerProfile.State,
	settings: settingsProfile.State,
}

export type ServerPlayerProfile = {
	player: Player,
	profileStore: Reflex.Producer<any, any> & { Data: Data },
	producer: Reflex.Producer<any, any>
		& gameProfile.Producer
		& inventoryProfile.Producer
		& playerProfile.Producer
		& settingsProfile.Producer
		& {
			getState: () -> Data,
		},
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

local DATASTORE_KEY: string = "PlayerData_v1"
local function getPlayerKey(userId: number): string
	return "Player_" .. userId
end

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

local SAVE_EXCEPTIONS = {
	"userId",
}

function ServerData:GetPlayerProfile(player: Player): ServerPlayerProfile?
	return self.profiles[player]
end

function ServerData:WaitForPlayerProfile(player: Player): Promise.TypedPromise<ServerPlayerProfile>
	return Promise.new(function(resolve: (ServerPlayerProfile) -> ()): ()
		local profile = self:GetPlayerProfile(player)
		local connection

		if profile then
			resolve(profile)
			return
		end

		connection = self.playerDataLoadedEvent:Connect(function(newPlayer: Player, data: ServerPlayerProfile): ()
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

	profileStore:ListenToRelease(function(): ()
		self.profiles[player] = nil
		player:Kick("Your data has been loaded on another server.")
	end)

	if not player:IsDescendantOf(Players) then
		profileStore:Release()
		return
	end

	local data = profileStore.Data
	data.userId = player.UserId

	local playerProducer = playerProfile.CreateProducer(data)
	local settingsProducer = settingsProfile.CreateProducer(data.settings or settingsProfile.DEFAULT_STATE)
	local inventoryProducer = inventoryProfile.CreateProducer(data.inventory or inventoryProfile.DEFAULT_STATE)

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

	local replicateMiddleware: Reflex.Middleware = function(): ((...any) -> any, string) -> (...any) -> any
		return function(dispatch: (...any) -> any, name: string): (...any) -> any
			return function(...: any): any
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

	self.gameProducer:incrementActivePlayers()
end

function ServerData:PlayerRemoving(player: Player): ()
	local profile: ServerPlayerProfile? = self.profiles[player]
	if not profile then
		return
	end

	local combinedState = profile.producer:getState()
	print("PlayerRemoving - Combined state before saving:")
	print("combinedState:", combinedState)
	print("combinedState.player:", combinedState.player)
	print("combinedState.player.coins:", combinedState.player.coins)
	print("combinedState.settings:", combinedState.settings)
	print("combinedState.inventory:", combinedState.inventory)

	print("PlayerRemoving - Checking for nested fields in playerState:")
	print("playerState.settings:", combinedState.player.settings)
	print("playerState.inventory:", combinedState.player.inventory)

	local saveableData = {}

	local playerState = combinedState.player
	for key, value in playerState do
		if table.find(SAVE_EXCEPTIONS, key) ~= nil then
			continue
		end

		if typeof(value) == "string" and not IsValidUTF8(value) then
			continue
		end

		saveableData[key] = value
	end

	saveableData.settings = combinedState.settings
	saveableData.inventory = combinedState.inventory

	print("PlayerRemoving - Saveable data structure:")
	print("saveableData:", saveableData)
	print("saveableData.coins:", saveableData.coins)
	print("saveableData.settings:", saveableData.settings)
	print("saveableData.inventory:", saveableData.inventory)

	profile.profileStore.Data = saveableData
	profile.profileStore:Release()
	self.profiles[player] = nil

	self.gameProducer:decrementActivePlayers()
end

function ServerData:Init(): ()
	self.gameProducer = gameProfile.CreateProducer(gameProfile.DEFAULT_STATE)

	local nextActionIsReplicated: boolean = false

	local replicateMiddleware: Reflex.Middleware = function(): ((...any) -> any, string) -> (...any) -> any
		return function(dispatch: (...any) -> any, name: string): (...any) -> any
			return function(...: any): any
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

	ReplicateStore.OnServerEvent:Connect(function(player: Player, data: { name: string, [string]: any }): ()
		if type(data) ~= "table" then
			return
		end

		local isSecureAction: number? = data.name:find("^secure")
		if isSecureAction then
			warn("Player tried to replicate secure reflex action", data.name)
			return
		end

		local profile: ServerPlayerProfile? = self:GetPlayerProfile(player)
		if not profile then
			return
		end

		profile.nextActionIsReplicated = true
		(profile.producer :: any)[data.name](unpack(data.arguments))
	end)

	ReplicateGameStore.OnServerEvent:Connect(function(_player: Player, data: { name: string, [string]: any }): ()
		if type(data) ~= "table" then
			return
		end

		local isSecureAction: number? = data.name:find("^secure")
		if isSecureAction then
			warn("Player tried to replicate secure reflex action", data.name)
			return
		end

		nextActionIsReplicated = true
		self.gameProducer[data.name](unpack(data.arguments))
	end)

	GetPlayerData.OnServerInvoke = function(player: Player): ...any
		local profile: ServerPlayerProfile? = self:GetPlayerProfile(player)
		if not profile then
			return nil
		end

		local combinedState = profile.producer:getState()
		local clientData = {
			userId = combinedState.player.userId,
			coins = combinedState.player.coins,
			inventory = combinedState.inventory,
			settings = combinedState.settings,
		}

		return clientData
	end

	GetGameData.OnServerInvoke = function(): ...any
		return self.gameProducer:getState()
	end

	Players.PlayerRemoving:Connect(function(player: Player): ()
		self:PlayerRemoving(player)
	end)

	for _index: number, player: Player in Players:GetPlayers() do
		task.spawn(function(): ()
			self:PlayerAdded(player)
		end)
	end
end

return ServerData
