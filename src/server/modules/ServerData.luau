local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local GetBridge = require(ReplicatedStorage.util.GetBridge)
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
	slices: { string },
}

export type Default = {
	index: number,
	type: string,
	gameProducer: gameProfile.Producer,
	profiles: { [Player]: ServerPlayerProfile? },
	playerDataLoadedEvent: Signal.Signal<Player, ServerPlayerProfile>,
	GetPlayerProfile: (self: Default, player: Player) -> ServerPlayerProfile?,
	WaitForPlayerProfile: (self: Default, player: Player) -> Promise.TypedPromise<ServerPlayerProfile>,
	GetPlayerProducerAsync: (self: Default, player: Player) -> Promise.TypedPromise<ProfileTypes.PlayerProducer>,
	GetGameProducerAsync: (self: Default) -> Promise.TypedPromise<gameProfile.Producer>,
	PlayerAdded: (self: Default, player: Player) -> (),
	PlayerRemoving: (self: Default, player: Player) -> (),
	Init: (self: Default) -> (),
}

local ServerData: Default = {} :: Default
ServerData.index = 0
ServerData.type = "controller"
ServerData.profiles = {}
ServerData.playerDataLoadedEvent = Signal.new()

local PlayerReady = GetBridge("PlayerReady")

local DATASTORE_KEY: string = GameConfig.data.datastoreKey
local function getPlayerKey(userId: number): string
	return GameConfig.data.playerKeyPattern:format(userId)
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

function ServerData:GetPlayerProducerAsync(player: Player): Promise.TypedPromise<ProfileTypes.PlayerProducer>
	return Promise.new(function(resolve: (ProfileTypes.PlayerProducer) -> ()): ()
		local profile = self:WaitForPlayerProfile(player):expect()
		resolve(profile and profile.producer or nil)
	end)
end

function ServerData:GetGameProducerAsync(): Promise.TypedPromise<gameProfile.Producer>
	return Promise.new(function(resolve: (gameProfile.Producer) -> (), reject: (string) -> ()): ()
		if not self.gameProducer then
			reject(
				`Game producer not initialized yet! Change calling controller index to higher number than {self.index}!`
			)
		end

		resolve(self.gameProducer)
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

	playerData.ready = false
	playerData.userId = player.UserId

	producers.player = playerProfile.CreateProducer(MergeDictionaries(playerProfile.DEFAULT_STATE, playerData))
	local slices: { string } = {}
	table.insert(slices, "player")

	for key: string, module: any in profileModules do
		if key == "player" or key == "game" then
			continue
		end

		if not module.SLICE then
			continue
		end

		table.insert(slices, module.SLICE)

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
		slices = slices,
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

	profile.producer.secureFirstTime()

	task.defer(self.gameProducer.incrementActivePlayers)
end

function ServerData:PlayerRemoving(player: Player): ()
	local profile: ServerPlayerProfile? = self.profiles[player]
	if not profile then
		return
	end

	profile.producer.secureSetLastSeenTimestamp()

	local combinedState = profile.producer:getState()

	local saveableData = {}
	local exceptions = {}

	for _, module in getProfileModules() do
		if module.SAVE_EXCEPTIONS and module.SLICE then
			exceptions[module.SLICE] = module.SAVE_EXCEPTIONS
		end
	end

	for sliceName, stateSlice in combinedState do
		local data = {}

		if not table.find(profile.slices, sliceName) then
			continue
		end

		local sliceExceptions = exceptions[sliceName] or {}
		for key, value in stateSlice do
			if table.find(sliceExceptions, key) ~= nil then
				continue
			end

			if typeof(value) == "string" and not IsValidUTF8(value) then
				continue
			end

			data[key] = value
		end

		saveableData[sliceName] = data
	end

	saveableData.player.lastOnline = workspace:GetServerTimeNow()

	profile.profileStore.Data = saveableData :: any
	profile.profileStore:Release()
	self.profiles[player] = nil

	self.gameProducer.decrementActivePlayers()
end

function ServerData:Init(): ()
	PlayerReady:Connect(function(player: Player): ()
		ServerData:GetPlayerProducerAsync(player):expect().setPlayerReady()
	end)

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
		local profile: ServerPlayerProfile? = select(
			2,
			self:WaitForPlayerProfile(player):timeout(GameConfig.data.playerProfileInvokeTimeout, false):await()
		)
		if not profile then
			Logger.warn(`GetPlayerData: No profile found for {player.Name}`)

			return
		end

		return profile.producer:getState()
	end

	GetGameData.OnServerInvoke = function(): ...any
		return self.gameProducer:getState()
	end

	for _index: number, player: Player in Players:GetPlayers() do
		task.spawn(function(): ()
			self:PlayerAdded(player)
		end)
	end
end

return ServerData
