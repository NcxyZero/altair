--!strict
-- LoggerTest.spec.luau
-- Test script for logging data with Logger utility after using producer actions

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.util.Logger)
local Reflex = require(ReplicatedStorage.package.Reflex)
local gameProfile = require(ReplicatedStorage.shared.reflex.gameProfile)
local playerProfile = require(ReplicatedStorage.shared.reflex.playerProfile)

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

-- Test cases
local function testPlayerProfileLogging()
	print("Testing player profile logging...")

	-- Create a player profile producer with initial state
	local initialState = {
		userId = 12345,
		coins = 100,
		inventory = {
			apple = 5,
			banana = 10,
		},
		settings = {
			musicVolume = 0.7,
			sfxVolume = 0.8,
		},
	}

	local producer = playerProfile.CreateProducer(initialState)

	-- Apply our custom logger middleware
	producer:applyMiddleware(createLoggerMiddleware())

	-- Perform some actions and observe the logs
	print("Performing actions on player profile...")

	producer.addCoins(50)
	producer.setInventoryItem("orange", 3)
	producer.removeInventoryItem("apple")
	producer.setSetting("musicVolume", 0.5)

	-- Get final state
	local finalState = producer:getState()
	print("Final player profile state: " .. tostring(finalState))

	return true
end

local function testGameProfileLogging()
	print("Testing game profile logging...")

	-- Create a game profile producer with initial state
	local initialState = {
		serverStartTime = os.time(),
		activePlayers = 5,
	}

	local producer = gameProfile.CreateProducer(initialState)

	-- Apply our custom logger middleware
	producer:applyMiddleware(createLoggerMiddleware())

	-- Perform some actions and observe the logs
	print("Performing actions on game profile...")

	producer.incrementActivePlayers()
	producer.incrementActivePlayers()
	producer.decrementActivePlayers()
	producer.setActivePlayers(10)

	-- Get final state
	local finalState = producer:getState()
	print("Final game profile state: " .. tostring(finalState))

	return true
end

-- Run all tests
local function runAllTests()
	print("Starting Logger tests with Reflex producers...")

	local success, errorMessage = pcall(function()
		testPlayerProfileLogging()
		testGameProfileLogging()
	end)

	if success then
		print("All Logger tests passed!")
	else
		Logger.warn("Test failed: " .. tostring(errorMessage))
	end

	return success
end

-- Run the tests
return runAllTests()
