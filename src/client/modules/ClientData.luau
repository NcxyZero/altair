local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.package.Promise)
local Reflex = require(ReplicatedStorage.package.Reflex)
local Signal = require(ReplicatedStorage.package.Signal)

-- Import profile producers
local gameProfile = require(ReplicatedStorage.shared.reflex.gameProfile)
local inventoryProfile = require(ReplicatedStorage.shared.reflex.inventoryProfile)
local playerProfile = require(ReplicatedStorage.shared.reflex.playerProfile)
local settingsProfile = require(ReplicatedStorage.shared.reflex.settingsProfile)

export type Default = {
	index: number,
	type: string,
	path: { [string]: any }?,
	clientProducer: Reflex.Producer<any, any>,
	playerProducer: Reflex.Producer<any, any>,
	gameProducer: Reflex.Producer<any, any>,
	isPlayerDataLoaded: boolean,
	isGameDataLoaded: boolean,
	playerDataLoadedSignal: Signal.Signal<()>,
	gameDataLoadedSignal: Signal.Signal<()>,
	getPlayerProducerAsync: (self: Default) -> Promise.TypedPromise<any>,
	getGameProducerAsync: (self: Default) -> Promise.TypedPromise<any>,
	PlayerAdded: (self: Default, player: Player) -> (),
	Start: (self: Default) -> (),
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

function ClientData:getPlayerProducerAsync(): Promise.TypedPromise<Reflex.Producer<any, any>>
	return Promise.new(function(resolve: (Reflex.Producer<any, any>) -> ()): ()
		if not self.isPlayerDataLoaded then
			self.playerDataLoadedSignal:Wait()
		end

		resolve(self.playerProducer)
	end)
end

function ClientData:getGameProducerAsync(): Promise.TypedPromise<Reflex.Producer<any, any>>
	return Promise.new(function(resolve: (Reflex.Producer<any, any>) -> ()): ()
		if not self.isGameDataLoaded then
			self.gameDataLoadedSignal:Wait()
		end

		resolve(self.gameProducer)
	end)
end

function ClientData:PlayerAdded(player: Player): ()
	if player ~= Players.LocalPlayer then
		return
	end
end

function ClientData:Start(): ()
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

		local playerProducer = playerProfile.CreateProducer(playerData)
		local settingsProducer = settingsProfile.CreateProducer(playerData.settings or settingsProfile.DEFAULT_STATE)
		local inventoryProducer =
			inventoryProfile.CreateProducer(playerData.inventory or inventoryProfile.DEFAULT_STATE)

		self.playerProducer = Reflex.combineProducers({
			player = playerProducer,
			settings = settingsProducer,
			inventory = inventoryProducer,
		})

		self.playerProducer:applyMiddleware(replicateMiddleware)
		self.isPlayerDataLoaded = true
		self.playerDataLoadedSignal:Fire()

		return
	end

	local function loadGameData(): (() -> ())?
		local gameData = ReplicatedStorage:WaitForChild("GetGameData"):InvokeServer()
		if not gameData then
			task.wait(0.5)
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
			warn("Queued store action before player data loaded")
			self.playerDataLoadedSignal:Wait()
		end

		local actionParts: { string } = string.split(data.name, "_")
		if #actionParts == 2 then
			if self.playerProducer[data.name] then
				self.playerProducer[data.name](unpack(data.arguments))
			else
				warn("Unknown action:", data.name)
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
			warn("Queued game store action before game data loaded")
			self.gameDataLoadedSignal:Wait()
		end

		if self.gameProducer[data.name] then
			self.gameProducer[data.name](unpack(data.arguments))
		else
			warn("Unknown game action:", data.name)
		end
	end)

	loadPlayerData()
	loadGameData()
end

ClientData:Start()

return ClientData
