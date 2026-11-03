local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local Logger = require(ReplicatedStorage.util.Core.Logger)
local MonetizationConfig = require(ReplicatedStorage.shared.config.MonetizationConfig)
local Reflex = require(ReplicatedStorage.package.Reflex)

export type Producer = Reflex.Producer<State, Actions>

export type State = {
	passes: { [string]: boolean },
	offers: { [string]: boolean },
	purchaseIds: { string },
	totalMoneyBought: number,
}

type Actions = {
	secureAddGamePass: (name: string) -> State,
	secureAddOffer: (name: string) -> State,
	secureAddPurchaseId: (purchaseId: string) -> State,
	secureAddTotalMoneyBought: (amount: number) -> State,
}

local MAXIMUM_PURCHASE_IDS: number = 50 -- granted receipt PurchaseIds kept per player; the oldest is dropped first

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
	purchaseIds = {}, -- PurchaseIds of granted developer product receipts, so a re-delivered receipt is not granted twice
	totalMoneyBought = 0,
}

function CreateProducer(initialState: State): Producer
	local producer: Producer = Reflex.createProducer(initialState, {
		secureAddGamePass = function(oldState: State, name: string): State
			local state: State = table.clone(oldState)
			state.passes = table.clone(oldState.passes)
			state.passes[name] = true

			return state
		end,

		secureAddOffer = function(oldState: State, name: string): State
			local state: State = table.clone(oldState)
			state.offers = table.clone(oldState.offers)

			if state.offers[name] ~= nil or GameConfig.core.monetizationOfferCreationAllowed then
				state.offers[name] = true
			else
				Logger.error(
					`Attempt to create a monetization offer despite the game config entry disallowing it (the offer is missing in MonetizationConfig). Offer name: "{name}".`
				)
			end

			return state
		end,

		-- Called by ServerMonetization in the same step as a receipt's grant, so the grant and its PurchaseId are saved together.
		secureAddPurchaseId = function(oldState: State, purchaseId: string): State
			if type(purchaseId) ~= "string" or purchaseId == "" then
				return oldState
			end

			local purchaseIds: { string } = if type(oldState.purchaseIds) == "table" then oldState.purchaseIds else {}
			if table.find(purchaseIds, purchaseId) then
				return oldState
			end

			local state: State = table.clone(oldState)
			state.purchaseIds = table.clone(purchaseIds)

			table.insert(state.purchaseIds, purchaseId)

			while #state.purchaseIds > MAXIMUM_PURCHASE_IDS do
				table.remove(state.purchaseIds, 1)
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
