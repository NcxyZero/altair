-- Auto-generated file - do not edit manually!
-- This file provides combined profile state and producer types

-- Keys discovered under src/shared/reflex: inventory monetization player settings

local inventoryProfile = require(script.Parent.inventoryProfile)
local monetizationProfile = require(script.Parent.monetizationProfile)
local playerProfile = require(script.Parent.playerProfile)
local settingsProfile = require(script.Parent.settingsProfile)

export type PlayerState = {
	inventory: typeof(inventoryProfile.DEFAULT_STATE),
	monetization: typeof(monetizationProfile.DEFAULT_STATE),
	player: typeof(playerProfile.DEFAULT_STATE),
	settings: typeof(settingsProfile.DEFAULT_STATE),
}

export type PlayerProducer =
	typeof(inventoryProfile.CreateProducer(inventoryProfile.DEFAULT_STATE))
	& typeof(monetizationProfile.CreateProducer(monetizationProfile.DEFAULT_STATE))
	& typeof(playerProfile.CreateProducer(playerProfile.DEFAULT_STATE))
	& typeof(settingsProfile.CreateProducer(settingsProfile.DEFAULT_STATE))
	& { getState: (self: unknown) -> PlayerState }

return table.freeze({})
