local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder: Folder = ReplicatedStorage:WaitForChild("shared") :: Folder
local _typesFolder: Folder = sharedFolder:WaitForChild("types") :: Folder
local reflexFolder: Folder = sharedFolder:WaitForChild("reflex") :: Folder

local ClientActionRegistry = require(ReplicatedStorage.shared.reflex.ClientActionRegistry)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local LocalPlayer = require(ReplicatedStorage.util.LocalPlayer)
local Logger = require(ReplicatedStorage.util.Logger)
local Maid = require(ReplicatedStorage.package.Maid)
local MergeDictionaries = require(ReplicatedStorage.util.MergeDictionaries)
local ProfileTypes = require(ReplicatedStorage.shared.reflex.ProfileTypes)
local Promise = require(ReplicatedStorage.package.Promise)
local Reflex = require(ReplicatedStorage.package.Reflex)
local Signal = require(ReplicatedStorage.package.Signal)
local clientProfile = require(ReplicatedStorage.shared.reflex.clientProfile)
local gameProfile = require(ReplicatedStorage.shared.reflex.gameProfile)

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

export type Default = {
	ApplyGameReplication: (self: Default, data: { [string]: any }) -> (),
	GetClientProducerAsync: (self: Default) -> Promise.TypedPromise<clientProfile.Producer>,
	GetGameProducerAsync: (self: Default) -> Promise.TypedPromise<gameProfile.Producer>,
	GetPlayerProducerAsync: (self: Default) -> Promise.TypedPromise<ProfileTypes.PlayerProducer>,
	Init: (self: Default) -> (),
	PlayerAdded: (self: Default, player: Player) -> (),
	pendingGameReplications: { { [string]: any } },
	index: number,
	isGameDataLoaded: boolean,
	isPlayerDataLoaded: boolean,
	type: string,
	clientProducer: clientProfile.Producer,
	gameProducer: gameProfile.Producer,
	path: InitializerTypes.ClientPath,
	playerProducer: ProfileTypes.PlayerProducer,
	gameDataLoadedSignal: Signal.Signal<()>,
	maid: Maid.Maid,
	playerDataLoadedSignal: Signal.Signal<()>,
}

local ClientData: Default = {
	index = 0,
	type = "controller",
	isPlayerDataLoaded = false,
	isGameDataLoaded = false,
	playerDataLoadedSignal = Signal.new(),
	gameDataLoadedSignal = Signal.new(),
	maid = Maid.new(),
	pendingGameReplications = {},
} :: Default

local clientActions: ClientActionRegistry.Registry = ClientActionRegistry.Build(getProfileModules())
local playerDataQueue: number = 0

local function CreateClientProducer(data: any): Reflex.Producer<any, any>
	local producer: Reflex.Producer<any, any> = Reflex.createProducer(data, {})

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

function ClientData:GetClientProducerAsync(): Promise.TypedPromise<clientProfile.Producer>
	return Promise.new(function(resolve: (clientProfile.Producer) -> ()): ()
		if not self.clientProducer then
			self.playerDataLoadedSignal:Wait()
		end

		resolve(self.clientProducer)
	end)
end

function ClientData:GetGameProducerAsync(): Promise.TypedPromise<gameProfile.Producer>
	return Promise.new(function(resolve: (gameProfile.Producer) -> (), reject: (string) -> ()): ()
		if not self.isGameDataLoaded then
			self.gameDataLoadedSignal:Wait()
		end

		if not self.gameProducer then
			reject(
				`Game producer not initialized yet! Change calling controller index to higher number than {self.index}!`
			)
		end

		resolve(self.gameProducer)
	end)
end

function ClientData:PlayerAdded(player: Player): ()
	if player ~= LocalPlayer then
		return
	end
end

function ClientData:ApplyGameReplication(data: { [string]: any }): ()
	if type(data) ~= "table" then
		return
	end

	if not self.isGameDataLoaded then
		table.insert(self.pendingGameReplications, data)

		return
	end

	local actionNameAny: any = data.name
	local actionName: string? = type(actionNameAny) == "string" and actionNameAny or nil
	if not actionName or type(data.arguments) ~= "table" then
		return
	end

	local action: any = self.gameProducer[actionName]
	if type(action) ~= "function" then
		Logger.warn("Unknown game action:", actionName)

		return
	end

	action(unpack(data.arguments))
end

function ClientData:Init(): ()
	self.maid:DoCleaning()

	table.clear(self.pendingGameReplications)

	self.clientProducer = CreateClientProducer(clientProfile.DEFAULT_STATE)

	local function loadPlayerData(): ()
		local playerData = ReplicatedStorage:WaitForChild("GetPlayerData"):InvokeServer()
		if not playerData then
			task.wait(0.5)
			return loadPlayerData()
		end

		local replicateMiddleware = function(): ()
			return function(dispatch: (...any) -> (...any) -> any, name: string): (...any) -> any
				return function(...: any): any
					if playerDataQueue >= 1 then
						playerDataQueue -= 1

						return dispatch(...)
					end

					local payload: { [string]: any } = {
						name = name,
						arguments = { ... },
					}
					local actionName: string? = ClientActionRegistry.Resolve(clientActions, payload)
					if actionName then
						ReplicatedStorage:WaitForChild("ReplicateStore"):FireServer(payload)
					end

					return dispatch(...)
				end
			end
		end

		local modules = getProfileModules()
		local producers = {}

		for key: string, module: any in modules do
			local state = playerData[key]
			local initialState = state and MergeDictionaries(module.DEFAULT_STATE, state) or module.DEFAULT_STATE

			producers[key] = module.CreateProducer(initialState)
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

		self.gameProducer = gameProfile.CreateProducer(gameData)
		self.isGameDataLoaded = true

		for _index: number, data: { [string]: any } in self.pendingGameReplications do
			self:ApplyGameReplication(data)
		end

		table.clear(self.pendingGameReplications)

		self.gameDataLoadedSignal:Fire()

		return
	end

	self.maid:GiveTask(
		ReplicatedStorage:WaitForChild("ReplicateStore").OnClientEvent
			:Connect(function(data: { name: string, arguments: { any } }): ()
				if type(data) ~= "table" then
					return
				end

				if not self.isPlayerDataLoaded then
					return
				end

				local actionNameAny: any = data.name
				local actionName: string? = type(actionNameAny) == "string" and actionNameAny or nil
				if not actionName then
					return
				end

				local action: any = self.playerProducer[actionName]
				if type(action) ~= "function" then
					Logger.warn("Unknown action:", actionName)

					return
				end

				playerDataQueue += 1

				action(unpack(data.arguments))
			end)
	)

	self.maid:GiveTask(
		ReplicatedStorage:WaitForChild("ReplicateGameStore").OnClientEvent:Connect(function(data: { [string]: any }): ()
			self:ApplyGameReplication(data)
		end)
	)

	loadPlayerData()
	loadGameData()
end

return ClientData
