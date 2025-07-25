--!strict
-- LoggerClientTest.client.luau
-- Client-side test script for logging data with Logger utility after using producer actions

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientData = require(script.Parent.Parent.modules.ClientData)
local Logger = require(ReplicatedStorage.util.Logger)

-- Custom middleware that uses our Logger utility
local function createLoggerMiddleware()
	return function(producer)
		print("[Reflex-Logger]: Mounted with state " .. tostring(producer:getState()))

		producer:subscribe(function(state)
			print("[Reflex-Logger]: State changed to " .. tostring(state))
		end)

		return function(dispatch, name)
			return function(...)
				local arguments = table.pack(...)
				local argStrings = {}

				for index = 1, arguments.n do
					table.insert(argStrings, tostring(arguments[index]))
				end

				print("[Reflex-Logger]: Dispatching " .. name .. "(" .. table.concat(argStrings, ", ") .. ")")

				return dispatch(...)
			end
		end
	end
end

-- Wait for player data to be loaded
local function waitForPlayerData()
	print("Waiting for player data to load...")

	ClientData:getPlayerProducerAsync():andThen(function(producer)
		print("Player data loaded successfully!")

		-- Apply our custom logger middleware
		producer:applyMiddleware(createLoggerMiddleware())

		-- Log initial state
		print("Initial player state: " .. tostring(producer:getState()))

		-- Perform some actions after a delay
		task.delay(2, function()
			print("Performing actions on player data...")

			-- Test player actions
			if producer.player_addCoins then
				producer.player_addCoins(25)
				print("Added 25 coins")
			end

			if producer.inventory_setInventoryItem then
				producer.inventory_setInventoryItem("gem", 5)
				print("Added 5 gems to inventory")
			end

			if producer.settings_setSetting then
				producer.settings_setSetting("musicVolume", 0.3)
				print("Changed music volume to 0.3")
			end

			-- Log final state
			print("Final player state after actions: " .. tostring(producer:getState()))
		end)
	end)
end

-- Wait for game data to be loaded
local function waitForGameData()
	print("Waiting for game data to load...")

	ClientData:getGameProducerAsync():andThen(function(producer)
		print("Game data loaded successfully!")

		-- Apply our custom logger middleware
		producer:applyMiddleware(createLoggerMiddleware())

		-- Log initial state
		print("Initial game state: " .. tostring(producer:getState()))
	end)
end

-- Initialize the test
local function init()
	print("Initializing Logger client test...")

	-- Wait for ClientData to initialize
	if not ClientData.isPlayerDataLoaded then
		ClientData.playerDataLoadedSignal:Wait()
	end

	-- Run tests
	waitForPlayerData()
	waitForGameData()

	print("Logger client test initialized!")
end

-- Start the test
init()
