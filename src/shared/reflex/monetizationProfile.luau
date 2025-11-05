local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local Logger = require(ReplicatedStorage.util.Logger)
local MonetizationConfig = require(ReplicatedStorage.shared.config.MonetizationConfig)
local Reflex = require(ReplicatedStorage.package.Reflex)

export type Producer = Reflex.Producer<State, Actions>

export type State = {
	passes: { [string]: boolean },
	offers: { [string]: boolean },
	totalMoneyBought: number,
}

type Actions = {
	secureAddGamePass: (name: string) -> State,
	secureAddOffer: (name: string) -> State,
	secureAddTotalMoneyBought: (amount: number) -> State,
}

local function fillGamePasses(): { [string]: boolean }
	local gamePasses: { [string]: any } = table.clone(MonetizationConfig.passes)
	for name: string in gamePasses do
		gamePasses[name] = false
	end

	return gamePasses
end

local DEFAULT_STATE: State = {
	passes = fillGamePasses(),
	offers = {
		starterPack = false,
	},
	totalMoneyBought = 0,
}

function CreateProducer(initialState: State): Producer
	local producer: Producer = Reflex.createProducer(initialState, {
		secureAddGamePass = function(oldState: State, name: string): State
			local state = table.clone(oldState)
			state.passes[name] = true

			return state
		end,

		secureAddOffer = function(oldState: State, name: string): State
			local state = table.clone(oldState)

			if state.offers[name] or GameConfig.core.monetizationOfferCreationAllowed then
				state.offers[name] = true
			else
				Logger.error(
					`Attempt to create a monetization offer despite the game config entry disallowing it (the offer is missing in MonetizationConfig). Offer name: "{name}".`
				)
			end

			return state
		end,

		secureAddTotalMoneyBought = function(oldState: State, amount: number): State
			local state = table.clone(oldState)
			state.totalMoneyBought += math.abs(amount)

			return state
		end,
	})

	return producer
end

return {
	CreateProducer = CreateProducer,
	DEFAULT_STATE = DEFAULT_STATE,
}
