local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IsValidUTF8 = require(ReplicatedStorage.util.IsValidUTF8)
local Logger = require(ReplicatedStorage.util.Logger)
local MergeDictionaries = require(ReplicatedStorage.util.MergeDictionaries)
local ProfileService = require(ReplicatedStorage.package.ProfileService)
local ProfileTypes = require(ReplicatedStorage.shared.reflex.ProfileTypes)
local Promise = require(ReplicatedStorage.package.Promise)
local Reflex = require(ReplicatedStorage.package.Reflex)
local Signal = require(ReplicatedStorage.package.Signal)
local gameProfile = require(ReplicatedStorage.shared.reflex.gameProfile)
local playerProfile = require(ReplicatedStorage.shared.reflex.playerProfile)

local sharedFolder: Folder = ReplicatedStorage:WaitForChild("shared") :: Folder
local reflexFolder: Folder = sharedFolder:WaitForChild("reflex") :: Folder

type ProfileTypes = typeof(ProfileTypes)

local function getProfileModules(): { [string]: any }
	local modules: { [string]: any } = {}

	for _index: number, child: Instance in reflexFolder:GetChildren() do
		if child:IsA("ModuleScript") then
			local name: string = child.Name
			if name ~= "gameProfile" and name:match("Profile$") then
				local key: string = name:gsub("Profile$", "")
				modules[key] = require(child) :: any
			end
		end
	end

	return modules
end

export type Data = ProfileTypes.PlayerState

export type ServerPlayerProfile = {
	player: Player,
	profileStore: Reflex.Producer<any, any> & { Data: Data },
	producer: ProfileTypes.PlayerProducer,
	nextActionIsReplicated: boolean,
}

export type Default = {
	index: number,
	type: string,
	gameData: {},
	gameProducer: gameProfile.Producer,
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
	local profileModules = getProfileModules()

	local defaultTemplate = {}
	for key: string, module: any in profileModules do
		if key == "game" then
			continue
		end

		if key == "player" then
			defaultTemplate.player = playerProfile.DEFAULT_STATE
		else
			defaultTemplate[key] = module.DEFAULT_STATE
		end
	end

	if defaultTemplate.player == nil then
		defaultTemplate.player = playerProfile.DEFAULT_STATE
	end

	local ProfileStore = ProfileService.GetProfileStore(DATASTORE_KEY, defaultTemplate)
	local profileStore = ProfileStore:LoadProfileAsync(getPlayerKey(player.UserId))
	if not profileStore then
		player:Kick("Failed to load your data. Please try again later.")

		return
	end

	profileStore:AddUserId(player.UserId)
	profileStore:Reconcile()

	profileStore:ListenToRelease(function(): ()
		self.profiles[player] = nil

		player:Kick("Your data has been loaded on another server.")
	end)

	if not player:IsDescendantOf(Players) then
		profileStore:Release()

		return
	end

	local data = profileStore.Data

	local producers = {}

	local playerData = data.player or {}
	playerData.userId = player.UserId

	producers.player = playerProfile.CreateProducer(MergeDictionaries(playerProfile.DEFAULT_STATE, playerData))

	for key: string, module: any in profileModules do
		if key == "player" or key == "game" then
			continue
		end

		local initialState
		if data[key] then
			initialState = MergeDictionaries(module.DEFAULT_STATE, data[key])
		else
			initialState = module.DEFAULT_STATE
		end

		producers[key] = module.CreateProducer(initialState)
	end

	local combinedProducer: ProfileTypes.PlayerProducer =
		Reflex.combineProducers(producers) :: ProfileTypes.PlayerProducer

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
	player:SetAttribute("DataLoaded", true)

	self.gameProducer:incrementActivePlayers()
end

function ServerData:PlayerRemoving(player: Player): ()
	local profile: ServerPlayerProfile? = self.profiles[player]
	if not profile then
		return
	end

	local combinedState = profile.producer:getState()
	local dataToSave = {}

	local playerState = combinedState.player
	local saveableData = {}
	for key, value in playerState do
		if table.find(SAVE_EXCEPTIONS, key) ~= nil then
			continue
		end

		if typeof(value) == "string" and not IsValidUTF8(value) then
			continue
		end

		saveableData[key] = value
	end

	dataToSave.player = saveableData

	for key: string, value: any in combinedState do
		if key == "player" then
			continue
		end

		dataToSave[key] = value
	end

	profile.profileStore.Data = dataToSave :: any
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
			Logger.warn("Player tried to replicate secure reflex action", data.name)
			return
		end

		local profile: ServerPlayerProfile? = self:GetPlayerProfile(player)
		if not profile then
			return
		end

		profile.nextActionIsReplicated = true

		do
			(profile.producer :: any)[data.name](unpack(data.arguments))
		end
	end)

	ReplicateGameStore.OnServerEvent:Connect(function(_player: Player, data: { name: string, [string]: any }): ()
		if type(data) ~= "table" then
			return
		end

		local isSecureAction: number? = data.name:find("^secure")
		if isSecureAction then
			Logger.warn("Player tried to replicate secure reflex action", data.name)
			return
		end

		nextActionIsReplicated = true
		self.gameProducer[data.name](unpack(data.arguments))
	end)

	GetPlayerData.OnServerInvoke = function(player: Player): ...any
		local profile: ServerPlayerProfile? = table.pack(self:WaitForPlayerProfile(player):timeout(5, false):await())[2]
		if not profile then
			Logger.warn(`GetPlayerData: No profile found for {player.Name}`)

			return nil
		end

		local combinedState = profile.producer:getState()

		return combinedState
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

	--! FOR SOLO TEST !--
	-- task.delay(5, function(): ()
	-- 	print(self:WaitForPlayerProfile(game:GetService("Players"):GetPlayers()[1]):expect().producer:getState())
	-- end)
end

return ServerData
