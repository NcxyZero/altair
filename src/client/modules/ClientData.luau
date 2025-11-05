local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local LocalPlayer = require(ReplicatedStorage.util.LocalPlayer)
local Logger = require(ReplicatedStorage.util.Logger)
local ProfileTypes = require(ReplicatedStorage.shared.reflex.ProfileTypes)
local Promise = require(ReplicatedStorage.package.Promise)
local Reflex = require(ReplicatedStorage.package.Reflex)
local Signal = require(ReplicatedStorage.package.Signal)
local gameProfile = require(ReplicatedStorage.shared.reflex.gameProfile)

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

export type Default = {
	index: number,
	type: string,
	path: InitializerTypes.ClientPath,
	clientProducer: Reflex.Producer<any, any>,
	playerProducer: ProfileTypes.PlayerProducer,
	gameProducer: gameProfile.Producer,
	isPlayerDataLoaded: boolean,
	isGameDataLoaded: boolean,
	playerDataLoadedSignal: Signal.Signal<()>,
	gameDataLoadedSignal: Signal.Signal<()>,
	GetPlayerProducerAsync: (self: Default) -> Promise.TypedPromise<ProfileTypes.PlayerProducer>,
	GetGameProducerAsync: (self: Default) -> Promise.TypedPromise<gameProfile.Producer>,
	PlayerAdded: (self: Default, player: Player) -> (),
	Init: (self: Default) -> (),
}

local ClientData: Default = {
	index = 0,
	type = "controller",
	isPlayerDataLoaded = false,
	isGameDataLoaded = false,
	playerDataLoadedSignal = Signal.new(),
	gameDataLoadedSignal = Signal.new(),
} :: Default

local nextActionIsReplicated: boolean = false

local DEFAULT_CLIENT_STATE = {
	localSettings = {
		musicVolume = 0.5,
		sfxVolume = 0.5,
	},
}

local function CreateClientProducer(data: any): Reflex.Producer<any, any>
	local producer: Reflex.Producer<any, any> = Reflex.createProducer(data, {
		setLocalSetting = function(state: any, key: string, value: any): any
			local nextState = table.clone(state)
			nextState.localSettings = table.clone(state.localSettings)
			nextState.localSettings[key] = value

			return nextState
		end,
	})

	return producer
end

function ClientData:GetPlayerProducerAsync(): Promise.TypedPromise<ProfileTypes.PlayerProducer>
	return Promise.new(function(resolve: (ProfileTypes.PlayerProducer) -> ()): ()
		if not self.isPlayerDataLoaded then
			self.playerDataLoadedSignal:Wait()
		end

		resolve(self.playerProducer)
	end)
end

function ClientData:GetGameProducerAsync(): Promise.TypedPromise<gameProfile.Producer>
	return Promise.new(function(resolve: (gameProfile.Producer) -> ()): ()
		if not self.isGameDataLoaded then
			self.gameDataLoadedSignal:Wait()
		end

		resolve(self.gameProducer)
	end)
end

function ClientData:PlayerAdded(player: Player): ()
	if player ~= LocalPlayer then
		return
	end
end

function ClientData:Init(): ()
	self.clientProducer = CreateClientProducer(DEFAULT_CLIENT_STATE)

	local function loadPlayerData(): ()
		local playerData = ReplicatedStorage:WaitForChild("GetPlayerData"):InvokeServer()
		if not playerData then
			task.wait(0.5)
			return loadPlayerData()
		end

		local replicateMiddleware = function(): ()
			return function(dispatch: (...any) -> (...any) -> any, name: string): (...any) -> any
				return function(...: any): any
					if nextActionIsReplicated then
						nextActionIsReplicated = false
						return dispatch(...)
					end

					ReplicatedStorage:WaitForChild("ReplicateStore"):FireServer({
						name = name,
						arguments = { ... },
					})

					return dispatch(...)
				end
			end
		end

		local modules = getProfileModules()
		local producers = {}

		for key: string, state: any in playerData do
			local module = modules[key]
			if module then
				producers[key] = module.CreateProducer(state or module.DEFAULT_STATE)
			end
		end

		self.playerProducer = Reflex.combineProducers(producers) :: ProfileTypes.PlayerProducer

		self.playerProducer:applyMiddleware(replicateMiddleware)
		self.isPlayerDataLoaded = true
		self.playerDataLoadedSignal:Fire()

		return
	end

	local function loadGameData(): (() -> ())?
		local gameData = ReplicatedStorage:WaitForChild("GetGameData"):InvokeServer()
		if not gameData then
			task.wait(0.2)
			return loadGameData()
		end

		local replicateMiddleware = function(): ()
			return function(dispatch: (...any) -> (...any) -> any, name: string): (...any) -> any
				return function(...: any): (...any) -> any
					if nextActionIsReplicated then
						nextActionIsReplicated = false
						return dispatch(...)
					end

					ReplicatedStorage:WaitForChild("ReplicateGameStore"):FireServer({
						name = name,
						arguments = { ... },
					})

					return dispatch(...)
				end
			end
		end

		self.gameProducer = gameProfile.CreateProducer(gameData)
		self.gameProducer:applyMiddleware(replicateMiddleware)
		self.isGameDataLoaded = true
		self.gameDataLoadedSignal:Fire()

		return
	end

	ReplicatedStorage:WaitForChild("ReplicateStore").OnClientEvent:Connect(function(data: { [string]: any }): ()
		if type(data) ~= "table" then
			return
		end

		nextActionIsReplicated = true

		if not self.isPlayerDataLoaded then
			Logger.print("Queued store action before player data loaded:", data.name)
			self.playerDataLoadedSignal:Wait()
		end

		local actionParts: { string } = string.split(data.name, "_")
		if #actionParts == 2 then
			if self.playerProducer[data.name] then
				self.playerProducer[data.name](unpack(data.arguments))
			else
				Logger.warn("Unknown action:", data.name)
			end
		else
			self.playerProducer[data.name](unpack(data.arguments))
		end
	end)

	ReplicatedStorage:WaitForChild("ReplicateGameStore").OnClientEvent:Connect(function(data: { [string]: any }): ()
		if type(data) ~= "table" then
			return
		end

		nextActionIsReplicated = true

		if not self.isGameDataLoaded then
			Logger.print("Queued game store action before game data loaded:", data.name)
			self.gameDataLoadedSignal:Wait()
		end

		if self.gameProducer[data.name] then
			self.gameProducer[data.name](unpack(data.arguments))
		else
			Logger.warn("Unknown game action:", data.name)
		end
	end)

	loadPlayerData()
	loadGameData()
end

return ClientData
