local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local Reflex = require(ReplicatedStorage.Packages.Reflex)
local Signal = require(ReplicatedStorage.Packages.Signal)

-- Import profile producers
local gameProfile = require(ReplicatedStorage.shared.reflex.gameProfile)
local playerProfile = require(ReplicatedStorage.shared.reflex.playerProfile)
local settingsProfile = require(ReplicatedStorage.shared.reflex.settingsProfile)
local inventoryProfile = require(ReplicatedStorage.shared.reflex.inventoryProfile)

export type Default = {
	index: number,
	type: string,
	playerProducer: any,
	gameProducer: any,
	isPlayerDataLoaded: boolean,
	isGameDataLoaded: boolean,
	playerDataLoadedSignal: Signal.Signal<()>,
	gameDataLoadedSignal: Signal.Signal<()>,
	getPlayerProducerAsync: () -> Promise.TypedPromise<any>,
	getGameProducerAsync: () -> Promise.TypedPromise<any>,
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

-- Default state for client-specific data
local DEFAULT_CLIENT_STATE = {
	localSettings = {
		musicVolume = 0.5,
		sfxVolume = 0.5,
	},
}

-- Create a producer for client-specific data
local function CreateClientProducer(data: any)
	local producer = Reflex.createProducer(data, {
		setLocalSetting = function(state, key: string, value: any)
			state.localSettings[key] = value
			return state
		end,
	})

	return producer
end

-- Async function to get player producer
function ClientData:getPlayerProducerAsync()
	return Promise.new(function(resolve)
		if not self.isPlayerDataLoaded then
			self.playerDataLoadedSignal:Wait()
		end

		resolve(self.playerProducer)
	end)
end

-- Async function to get game producer
function ClientData:getGameProducerAsync()
	return Promise.new(function(resolve)
		if not self.isGameDataLoaded then
			self.gameDataLoadedSignal:Wait()
		end

		resolve(self.gameProducer)
	end)
end

function ClientData:PlayerAdded(player: Player): ()
	-- This is a client module, so we don't need to handle other players
	if player ~= Players.LocalPlayer then
		return
	end
end

function ClientData:Init(): ()
	-- Create client-specific producer
	self.clientProducer = CreateClientProducer(DEFAULT_CLIENT_STATE)

	-- Load player data
	local function loadPlayerData()
		local playerData = ReplicatedStorage:WaitForChild("GetPlayerData"):InvokeServer()

		if not playerData then
			task.wait(0.5)
			return loadPlayerData()
		end

		local nextActionIsReplicated = false

		local replicateMiddleware = function()
			return function(dispatch, name)
				return function(...)
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

		-- Create individual producers
		local playerProducer = playerProfile.CreateProducer(playerData)
		local settingsProducer = settingsProfile.CreateProducer(playerData.settings or settingsProfile.DEFAULT_STATE)
		local inventoryProducer = inventoryProfile.CreateProducer(playerData.inventory or inventoryProfile.DEFAULT_STATE)

		-- Combine producers
		self.playerProducer = Reflex.combineProducers({
			player = playerProducer,
			settings = settingsProducer,
			inventory = inventoryProducer,
		})

		self.playerProducer:applyMiddleware(replicateMiddleware)
		self.isPlayerDataLoaded = true
		self.playerDataLoadedSignal:Fire()
	end

	-- Load game data
	local function loadGameData()
		local gameData = ReplicatedStorage:WaitForChild("GetGameData"):InvokeServer()

		if not gameData then
			task.wait(0.5)
			return loadGameData()
		end

		local nextActionIsReplicated = false

		local replicateMiddleware = function()
			return function(dispatch, name)
				return function(...)
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

		-- Use gameProfile module
		self.gameProducer = gameProfile.CreateProducer(gameData)
		self.gameProducer:applyMiddleware(replicateMiddleware)
		self.isGameDataLoaded = true
		self.gameDataLoadedSignal:Fire()
	end

	-- Set up remote events
	local nextActionIsReplicated = false

	ReplicatedStorage:WaitForChild("ReplicateStore").OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end

		nextActionIsReplicated = true

		if not self.isPlayerDataLoaded then
			warn("Queued store action before player data loaded")
			self.playerDataLoadedSignal:Wait()
		end

		-- Handle action based on naming convention
		-- Format: producerName_actionName
		local actionParts = string.split(data.name, "_")
		if #actionParts == 2 then
			local producerName = actionParts[1]
			local actionName = actionParts[2]

			-- Call the action on the appropriate producer
			if self.playerProducer[data.name] then
				self.playerProducer[data.name](unpack(data.arguments))
			else
				warn("Unknown action:", data.name)
			end
		else
			-- Fallback for actions without producer prefix
			self.playerProducer[data.name](unpack(data.arguments))
		end
	end)

	ReplicatedStorage:WaitForChild("ReplicateGameStore").OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end

		nextActionIsReplicated = true

		if not self.isGameDataLoaded then
			warn("Queued game store action before game data loaded")
			self.gameDataLoadedSignal:Wait()
		end

		-- Call the action on the game producer
		if self.gameProducer[data.name] then
			self.gameProducer[data.name](unpack(data.arguments))
		else
			warn("Unknown game action:", data.name)
		end
	end)

	-- Start loading data
	task.spawn(loadPlayerData)
	task.spawn(loadGameData)
end

return ClientData
