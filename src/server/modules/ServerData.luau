local CollectionService = game:GetService("CollectionService")
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
local RodsConfig = require(ReplicatedStorage.shared.config.RodsConfig)
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
			if name ~= "gameProfile" and name ~= "clientProfile" and name:match("Profile$") then
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

local loadingProfiles: { [Player]: boolean } = {}
local gameStoreReady: { [Player]: boolean } = {}

local PlayerReady = GetBridge("PlayerReady")

local PLAYTIME_TICK_SECONDS: number = 10
local AUTO_FISH_RESUME_ENABLED_ATTRIBUTE: string = "AutoFishingResumeEnabled"
local AUTO_FISH_RESUME_POSITION_ATTRIBUTE: string = "AutoFishingResumePosition"
local AUTO_FISH_RESUME_CAST_ATTRIBUTE: string = "AutoFishingResumeCastPosition"
local AUTO_FISH_RESUME_LOOK_ATTRIBUTE: string = "AutoFishingResumeLookVector"
local AUTO_FISH_RESUME_BASE_RELATIVE_CAST_ATTRIBUTE: string = "AutoFishingResumeBaseRelativeCastPosition"
local BARRIER_COLLISION_MODEL_NAME: string = "BarrierCollision"

local function packVector3(position: Vector3): { [string]: number }
	return {
		x = position.X,
		y = position.Y,
		z = position.Z,
	}
end

local function isFishingRodTool(tool: Instance): boolean
	if not tool:IsA("Tool") then
		return false
	end

	if CollectionService:HasTag(tool, "FishingRod") or tool.Name == "FishingRod" then
		return true
	end

	local rodIdAttr: any = tool:GetAttribute("CurrentRodId") or tool:GetAttribute("RodId")
	if type(rodIdAttr) == "string" and RodsConfig[rodIdAttr] ~= nil then
		return true
	end

	return RodsConfig[tool.Name] ~= nil
end

local function getEquippedRodTool(player: Player): Tool?
	local character: Model? = player.Character
	if not character then
		return
	end

	for _index: number, child: Instance in character:GetChildren() do
		if isFishingRodTool(child) then
			return child :: Tool
		end
	end

	return
end

local function getBarrierBounds(barrier: Instance): (CFrame?, Vector3?)
	local collisionModel: Instance? = barrier:FindFirstChild(BARRIER_COLLISION_MODEL_NAME)
	if collisionModel and collisionModel:IsA("Model") then
		return collisionModel:GetBoundingBox()
	end

	if barrier:IsA("Model") then
		return barrier:GetBoundingBox()
	end

	if barrier:IsA("BasePart") then
		return barrier.CFrame, barrier.Size
	end

	local modelCandidate: Instance? = barrier:FindFirstChildWhichIsA("Model", true)
	if modelCandidate then
		return (modelCandidate :: Model):GetBoundingBox()
	end

	local partCandidate: Instance? = barrier:FindFirstChildWhichIsA("BasePart", true)
	if partCandidate then
		local part: BasePart = partCandidate :: any

		return part.CFrame, part.Size
	end

	return
end

local function isPointInsideBarrier(barrier: Instance, point: Vector3): boolean
	local orientation: CFrame?, size: Vector3? = getBarrierBounds(barrier)
	if not orientation or not size then
		return false
	end

	local localPoint: Vector3 = orientation:PointToObjectSpace(point)

	return math.abs(localPoint.X) <= size.X / 2 and math.abs(localPoint.Z) <= size.Z / 2
end

local function isPointInsideBaseModel(baseModel: Model, point: Vector3): boolean
	local baseRoot: Instance? = baseModel:FindFirstChild("Base") or baseModel
	local floorsContainer: Instance? = baseRoot and baseRoot:FindFirstChild("Floors") or baseRoot
	local sawBarrier: boolean = false
	if floorsContainer then
		for _index: number, floor: Instance in floorsContainer:GetChildren() do
			local barrier: Instance? = floor:FindFirstChild("Barrier", true)
			if barrier then
				sawBarrier = true

				if isPointInsideBarrier(barrier, point) then
					return true
				end
			end
		end
	end

	local globalBarrier: Instance? = baseModel:FindFirstChild("Barrier", true)
	if globalBarrier then
		sawBarrier = true

		if isPointInsideBarrier(globalBarrier, point) then
			return true
		end
	end

	if not sawBarrier then
		local baseCFrame: CFrame, baseSize: Vector3 = baseModel:GetBoundingBox()
		local localPoint: Vector3 = baseCFrame:PointToObjectSpace(point)
		return math.abs(localPoint.X) <= baseSize.X / 2 and math.abs(localPoint.Z) <= baseSize.Z / 2
	end

	return false
end

local function findBaseModelAtPoint(point: Vector3): Model?
	local maps: Instance? = workspace:FindFirstChild("Maps")
	local bases: Instance? = maps and maps:FindFirstChild("Bases")
	if not bases then
		bases = workspace:FindFirstChild("Bases")
	end
	if not bases then
		return
	end

	for _index: number, baseModel: Instance in bases:GetChildren() do
		if baseModel:IsA("Model") and isPointInsideBaseModel(baseModel, point) then
			return baseModel
		end
	end

	return
end

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

GetPlayerData.OnServerInvoke = function(player: Player): ...any
	local existingProfile: ServerPlayerProfile? = ServerData:GetPlayerProfile(player)
	if not existingProfile then
		ServerData:PlayerAdded(player)
	end

	local profile: ServerPlayerProfile? = select(
		2,
		ServerData:WaitForPlayerProfile(player):timeout(GameConfig.data.playerProfileInvokeTimeout, false):await()
	)
	if not profile then
		Logger.warn(`GetPlayerData: No profile found for {player.Name}`)

		return
	end

	return profile.producer:getState()
end

GetGameData.OnServerInvoke = function(player: Player): ...any
	if player then
		gameStoreReady[player] = true
	end

	if not ServerData.gameProducer then
		return gameProfile.DEFAULT_STATE
	end

	return ServerData.gameProducer:getState()
end

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
	if self.profiles[player] then
		return
	end

	if loadingProfiles[player] then
		return
	end

	loadingProfiles[player] = true

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

		loadingProfiles[player] = nil

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
		loadingProfiles[player] = nil

		return
	end

	local data = profileStore.Data
	if data.player.tutorial then
		data = {}
	end

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

		table.insert(slices, key)

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

	loadingProfiles[player] = nil
end

function ServerData:PlayerRemoving(player: Player): ()
	local profile: ServerPlayerProfile? = self.profiles[player]
	if not profile then
		gameStoreReady[player] = nil

		return
	end

	local resumeEnabled: boolean = player:GetAttribute("AutoFishing") == true
		or player:GetAttribute(AUTO_FISH_RESUME_ENABLED_ATTRIBUTE) == true
	if resumeEnabled and not getEquippedRodTool(player) then
		resumeEnabled = false
	end

	local resumePosition: { [string]: number }?
	local resumeCastPosition: { [string]: number }?
	local resumeLookVector: { [string]: number }?
	local resumeBaseRelativePosition: { [string]: number }?
	local resumeBaseRelativeLookVector: { [string]: number }?
	local resumeBaseRelativeCastPosition: { [string]: number }?
	local rootBasePivot: CFrame?

	if resumeEnabled then
		local character: Model? = player.Character
		local root: BasePart? = character and character:FindFirstChild("HumanoidRootPart") :: any
		if root and root:IsA("BasePart") then
			resumePosition = packVector3(root.Position)
			resumeLookVector = packVector3(root.CFrame.LookVector)

			local baseModel: Model? = findBaseModelAtPoint(root.Position)
			if baseModel then
				local basePivot: CFrame = baseModel:GetPivot()
				rootBasePivot = basePivot
				resumeBaseRelativePosition = packVector3(basePivot:PointToObjectSpace(root.Position))
				resumeBaseRelativeLookVector = packVector3(basePivot:VectorToObjectSpace(root.CFrame.LookVector))
			end
		end
	end

	if resumeEnabled and not resumePosition then
		local resumePositionAny: any = player:GetAttribute(AUTO_FISH_RESUME_POSITION_ATTRIBUTE)
		if typeof(resumePositionAny) == "Vector3" then
			resumePosition = packVector3(resumePositionAny)
		end
	end

	local resumeCastAny: any = player:GetAttribute(AUTO_FISH_RESUME_CAST_ATTRIBUTE)
	if resumeEnabled and typeof(resumeCastAny) == "Vector3" then
		resumeCastPosition = packVector3(resumeCastAny)
	end

	local resumeLookAny: any = player:GetAttribute(AUTO_FISH_RESUME_LOOK_ATTRIBUTE)
	if resumeEnabled and not resumeLookVector and typeof(resumeLookAny) == "Vector3" then
		resumeLookVector = packVector3(resumeLookAny)
	end

	if resumeEnabled and rootBasePivot and resumeCastPosition and not resumeBaseRelativeCastPosition then
		local castVector = Vector3.new(resumeCastPosition.x, resumeCastPosition.y, resumeCastPosition.z)
		resumeBaseRelativeCastPosition = packVector3(rootBasePivot:PointToObjectSpace(castVector))
	end

	if resumeEnabled and resumePosition and not resumeBaseRelativePosition then
		local resumePositionAny: any = player:GetAttribute(AUTO_FISH_RESUME_POSITION_ATTRIBUTE)
		local positionVector: Vector3 = typeof(resumePositionAny) == "Vector3" and resumePositionAny
			or Vector3.new(resumePosition.x, resumePosition.y, resumePosition.z)

		local baseModel: Model? = findBaseModelAtPoint(positionVector)
		if baseModel then
			local basePivot: CFrame = baseModel:GetPivot()
			resumeBaseRelativePosition = packVector3(basePivot:PointToObjectSpace(positionVector))

			if resumeLookVector then
				local lookVector: Vector3 = Vector3.new(resumeLookVector.x, resumeLookVector.y, resumeLookVector.z)
				resumeBaseRelativeLookVector = packVector3(basePivot:VectorToObjectSpace(lookVector))
			end

			if resumeCastPosition then
				local castVector: Vector3 =
					Vector3.new(resumeCastPosition.x, resumeCastPosition.y, resumeCastPosition.z)
				resumeBaseRelativeCastPosition = packVector3(basePivot:PointToObjectSpace(castVector))
			end
		end
	end

	if resumeEnabled and resumeCastPosition and not resumeBaseRelativeCastPosition then
		local resumeCastVector: Vector3 = Vector3.new(resumeCastPosition.x, resumeCastPosition.y, resumeCastPosition.z)
		local baseModel: Model? = findBaseModelAtPoint(resumeCastVector)
		if baseModel then
			local basePivot: CFrame = baseModel:GetPivot()
			resumeBaseRelativeCastPosition = packVector3(basePivot:PointToObjectSpace(resumeCastVector))
		end
	end

	if resumeEnabled and not resumeBaseRelativeCastPosition then
		local baseRelativeCastAny: any = player:GetAttribute(AUTO_FISH_RESUME_BASE_RELATIVE_CAST_ATTRIBUTE)
		if typeof(baseRelativeCastAny) == "Vector3" then
			resumeBaseRelativeCastPosition = packVector3(baseRelativeCastAny)
		end
	end

	if (profile.producer :: any).secureSetAutoFishResumeState then
		if resumeEnabled and resumePosition then
			Logger.print(
				`Auto fishing resume saved player={player.Name} pos=({math.floor(resumePosition.x + 0.5)}, {math.floor(
					resumePosition.y + 0.5
				)}, {math.floor(resumePosition.z + 0.5)}) cast={tostring(resumeCastPosition ~= nil)}`
			);
			(profile.producer :: any).secureSetAutoFishResumeState(
				true,
				resumePosition,
				resumeCastPosition,
				resumeLookVector,
				resumeBaseRelativePosition,
				resumeBaseRelativeLookVector,
				resumeBaseRelativeCastPosition
			)
		else
			Logger.print(
				`Auto fishing resume cleared player={player.Name} auto={tostring(player:GetAttribute("AutoFishing"))} resumeAttr={tostring(
					player:GetAttribute(AUTO_FISH_RESUME_ENABLED_ATTRIBUTE)
				)}`
			);
			(profile.producer :: any).secureSetAutoFishResumeState(false)
		end
	end

	profile.producer.secureSetLastSeenTimestamp()

	local combinedState = profile.producer:getState()

	local saveableData = {}
	local exceptions = {}

	for key: string, module in getProfileModules() do
		if module.SAVE_EXCEPTIONS then
			exceptions[key] = module.SAVE_EXCEPTIONS
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

	saveableData.player.lastOnline = math.floor(workspace:GetServerTimeNow())

	profile.profileStore.Data = saveableData :: any
	profile.profileStore:Release()
	self.profiles[player] = nil
	gameStoreReady[player] = nil
end

function ServerData:Init(): ()
	PlayerReady:Connect(function(player: Player): ()
		ServerData:GetPlayerProducerAsync(player):expect().setPlayerReady()
	end)

	task.spawn(function(): ()
		while true do
			task.wait(PLAYTIME_TICK_SECONDS)

			for _player: Player, profile: ServerPlayerProfile in self.profiles do
				if profile and profile.producer and (profile.producer :: any).secureAddTimePlayedSeconds then
					(profile.producer :: any).secureAddTimePlayedSeconds(PLAYTIME_TICK_SECONDS)
				end
			end
		end
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

				local payload = {
					name = name,
					arguments = { ... },
				}

				for _index: number, player: Player in Players:GetPlayers() do
					if gameStoreReady[player] then
						ReplicateGameStore:FireClient(player, payload)
					end
				end

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

	for _index: number, player: Player in Players:GetPlayers() do
		task.spawn(function(): ()
			self:PlayerAdded(player)
		end)
	end
end

return ServerData
