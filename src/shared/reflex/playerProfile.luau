local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reflex = require(ReplicatedStorage.package.Reflex)

export type Producer = Reflex.Producer<State, Actions>

export type State = {
	userId: number,
	coins: number,
	inventory: { [string]: number },
	settings: {
		musicVolume: number,
		sfxVolume: number,
	},
}

type Actions = {
	setCoins: (coins: number) -> (),
	addCoins: (amount: number) -> (),
	setInventoryItem: (itemId: string, amount: number) -> (),
	removeInventoryItem: (itemId: string) -> (),
	setSetting: (key: string, value: any) -> (),
}

local DEFAULT_STATE: State = {
	userId = 0,
	coins = 0,
	inventory = {},
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
		setCoins = function(state: State, coins: number): State
			state.coins = coins

			return state
		end,

		addCoins = function(state: State, amount: number): State
			state.coins += amount

			return state
		end,

		secureAddCoins = function(state: State, amount: number): State
			state.coins += amount

			return state
		end,

		setInventoryItem = function(state: State, itemId: string, amount: number): State
			state.inventory[itemId] = amount

			return state
		end,

		removeInventoryItem = function(state: State, itemId: string): State
			state.inventory[itemId] = nil

			return state
		end,

		setSetting = function(state: State, key: string, value: any): State
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
