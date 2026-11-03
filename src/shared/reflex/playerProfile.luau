local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConvertCurrency = require(ReplicatedStorage.util.Core.ConvertCurrency)
local Reflex = require(ReplicatedStorage.package.Reflex)

export type Producer = Reflex.Producer<State, Actions>

export type State = {
	userId: number,
	lastSeen: number,
	money: string,
	rebirth: number,
	redeemedCodes: { [string]: number },
	tutorialCompleted: boolean,
	tutorialStep: number,
}

type Actions = {
	setPlayerReady: () -> State,
	secureFirstTime: () -> State,
	secureSetLastSeenTimestamp: () -> State,
	secureAddMoney: (amount: number | string) -> State,
	secureSpendMoney: (amount: number | string) -> State,
	secureAddRebirth: (addMultipleAmount: number?) -> State,
	secureSetRebirth: (amount: number) -> State,
	secureSubtractRebirth: (amount: number) -> State,
	secureRedeemCode: (code: string, timestamp: number) -> State,
	secureRestartTutorial: () -> State,
	secureCompleteTutorial: () -> State,
}

local MAXIMUM_SAFE_INTEGER: number = 9_007_199_254_740_991 -- 2^53 - 1, the largest integer a number stores exactly

local DEFAULT_STATE: State = {
	userId = 0,
	lastSeen = DateTime.now().UnixTimestamp,
	money = "",
	rebirth = 0,
	redeemedCodes = {},
	tutorialCompleted = false,
	tutorialStep = 1,
}

local SAVE_EXCEPTIONS: { string } = {
	"userId",
}

local function normalizeNonnegativeInteger(rawValue: any): number
	local value: number = tonumber(rawValue) :: number
	if not value or value ~= value or math.abs(value) == math.huge then
		return 0
	end

	return math.clamp(value // 1, 0, MAXIMUM_SAFE_INTEGER)
end

-- An infinite money total never finishes in ConvertCurrency.NumberToString, and NaN would wipe the balance.
local function isFiniteNumber(value: number): boolean
	return value == value and math.abs(value) ~= math.huge
end

function CreateProducer(initialState: State): Producer
	local producer: Producer = Reflex.createProducer(initialState, {
		setPlayerReady = function(oldState: State): State
			local state = table.clone(oldState)
			state.ready = true

			return state
		end,

		secureFirstTime = function(oldState: State): State
			local state = table.clone(oldState)
			state.firstTime = false

			return state
		end,

		secureSetLastSeenTimestamp = function(oldState: State): State
			local state = table.clone(oldState)
			state.lastSeen = DateTime.now().UnixTimestamp

			return state
		end,

		secureAddMoney = function(oldState: State, amount: number | string): State
			local numAmount: number = tonumber(amount) or amount :: number
			local safeAmount: number = typeof(numAmount) == "number" and (numAmount :: number) or 0
			local total: number = ConvertCurrency.StringToNumber(oldState.money) + math.abs(safeAmount)
			if not isFiniteNumber(total) then
				return oldState
			end

			local state = table.clone(oldState)
			state.money = ConvertCurrency.NumberToString(total)

			return state
		end,

		secureSpendMoney = function(oldState: State, amount: number | string): State
			local numAmount: number = tonumber(amount) or amount :: number
			local safeAmount: number = typeof(numAmount) == "number" and (numAmount :: number) or 0
			local total: number = ConvertCurrency.StringToNumber(oldState.money) - math.abs(safeAmount)
			if not isFiniteNumber(total) then
				return oldState
			end

			local state = table.clone(oldState)
			state.money = ConvertCurrency.NumberToString(total)

			return state
		end,

		secureAddRebirth = function(oldState: State, addMultipleAmount: number?): State
			local amount: number = addMultipleAmount == nil and 1 or normalizeNonnegativeInteger(addMultipleAmount)
			if amount <= 0 then
				return oldState
			end

			local state: State = table.clone(oldState)
			state.rebirth = math.min(normalizeNonnegativeInteger(state.rebirth) + amount, MAXIMUM_SAFE_INTEGER)

			return state
		end,

		secureSetRebirth = function(oldState: State, amount: number): State
			local state: State = table.clone(oldState)
			state.rebirth = normalizeNonnegativeInteger(amount)

			return state
		end,

		secureSubtractRebirth = function(oldState: State, amount: number): State
			local state: State = table.clone(oldState)
			state.rebirth =
				math.max(normalizeNonnegativeInteger(state.rebirth) - normalizeNonnegativeInteger(amount), 0)

			return state
		end,

		secureRedeemCode = function(oldState: State, code: string, timestamp: number): State
			if type(code) ~= "string" or code == "" then
				return oldState
			end

			local redeemedCodes: { [string]: number } = if type(oldState.redeemedCodes) == "table"
				then oldState.redeemedCodes
				else {}
			if redeemedCodes[code] ~= nil then
				return oldState
			end

			local state: State = table.clone(oldState)
			state.redeemedCodes = table.clone(redeemedCodes)
			state.redeemedCodes[code] = normalizeNonnegativeInteger(timestamp)

			return state
		end,

		secureRestartTutorial = function(oldState: State): State
			local state: State = table.clone(oldState)
			state.tutorialCompleted = false
			state.tutorialStep = 1

			return state
		end,

		secureCompleteTutorial = function(oldState: State): State
			local state: State = table.clone(oldState)
			state.tutorialCompleted = true

			return state
		end,
	})

	return producer
end

return {
	CreateProducer = CreateProducer,
	DEFAULT_STATE = DEFAULT_STATE,
	SAVE_EXCEPTIONS = SAVE_EXCEPTIONS,
}
