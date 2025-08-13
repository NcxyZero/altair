local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reflex = require(ReplicatedStorage.package.Reflex)

export type Producer = Reflex.Producer<State, Actions>

export type State = {
	userId: number,
	coins: number,
	settings: {
		musicVolume: number,
		sfxVolume: number,
	},
}

type Actions = {
	secureAddCoins: (amount: number) -> (),
	secureSpendCoins: (price: number) -> (),
	setSetting: (key: string, value: any) -> (),
}

local DEFAULT_STATE: State = {
	userId = 0,
	coins = 0,
	settings = {
		musicVolume = 0.5,
		sfxVolume = 0.5,
	},
}

local SAVE_EXCEPTIONS: { string } = {
	"userId",
}

function CreateProducer(initialState: State): Producer
	local producer: Producer = Reflex.createProducer(initialState, {
		secureAddCoins = function(oldState: State, amount: number): State
			local state = table.clone(oldState)
			state.coins += math.abs(amount)

			return state
		end,

		secureSpendCoins = function(oldState: State, coins: number): State
			local state = table.clone(oldState)
			state.coins -= math.abs(coins)

			return state
		end,

		setSetting = function(oldState: State, key: string, value: any): State
			local state = table.clone(oldState)
			state.settings = table.clone(state.settings)
			state.settings[key] = value

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
