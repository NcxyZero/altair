local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConvertCurrency = require(ReplicatedStorage.util.ConvertCurrency)
local Reflex = require(ReplicatedStorage.package.Reflex)

export type Producer = Reflex.Producer<State, Actions>

export type State = {
	userId: number,
	lastSeen: number,
	money: string,
	rebirth: number,
}

type Actions = {
	secureSetLastSeenTimestamp: () -> State,
	secureAddMoney: (amount: number | string) -> State,
	secureSpendMoney: (amount: number | string) -> State,
	secureAddRebirth: (addMultipleAmount: number?) -> State,
}

local DEFAULT_STATE: State = {
	userId = 0,
	lastSeen = DateTime.now().UnixTimestamp,
	money = "",
	rebirth = 0,
}

local SAVE_EXCEPTIONS: { string } = {
	"userId",
}

function CreateProducer(initialState: State): Producer
	local producer: Producer = Reflex.createProducer(initialState, {
		secureSetLastSeenTimestamp = function(oldState: State): State
			local state = table.clone(oldState)
			state.lastSeen = DateTime.now().UnixTimestamp

			return state
		end,

		secureAddMoney = function(oldState: State, amount: number | string): State
			if type(amount) == "string" then
				amount = tonumber(amount) :: number
			end

			local state = table.clone(oldState)
			local convertedValue: string =
				ConvertCurrency.NumberToString(ConvertCurrency.StringToNumber(state.money) + math.abs(amount :: number))
			state.money = convertedValue

			return state
		end,

		secureSpendMoney = function(oldState: State, amount: number | string): State
			if type(amount) == "string" then
				amount = tonumber(amount) :: number
			end

			local state = table.clone(oldState)
			local convertedValue: string =
				ConvertCurrency.NumberToString(ConvertCurrency.StringToNumber(state.money) - math.abs(amount :: number))
			state.money = convertedValue

			return state
		end,

		secureAddRebirth = function(oldState: State, addMultipleAmount: number?): State
			local state = table.clone(oldState)
			state.rebirth += addMultipleAmount or 1

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
