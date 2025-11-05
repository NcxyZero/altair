local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileTypes = require(ReplicatedStorage.shared.reflex.ProfileTypes)
local Promise = require(ReplicatedStorage.package.Promise)
local Reflex = require(ReplicatedStorage.package.Reflex)
local gameProfile = require(ReplicatedStorage.shared.reflex.gameProfile)

export type ServerPlayerProfile = {
	player: Player,
	profileStore: Reflex.Producer<any, any> & { Data: ProfileTypes.PlayerState },
	producer: ProfileTypes.PlayerProducer,
	nextActionIsReplicated: boolean,
}

export type ClientPath = {
	controller: {
		ClientData: unknown & {
			clientProducer: Reflex.Producer<any, any>,
			playerProducer: ProfileTypes.PlayerProducer,
			gameProducer: gameProfile.Producer,
			GetPlayerProducerAsync: (self: unknown) -> Promise.TypedPromise<ProfileTypes.PlayerProducer>,
			GetGameProducerAsync: (self: unknown) -> Promise.TypedPromise<gameProfile.Producer>,
		},
		[string]: unknown,
	},
	module: {
		[string]: unknown,
	},
	local_tag: {
		[string]: unknown,
	},
	tag: {
		[string]: unknown,
	},
}

export type ServerPath = {
	controller: {
		ServerData: unknown & {
			gameProducer: gameProfile.Producer,
			GetPlayerProfile: (self: unknown, player: Player) -> ServerPlayerProfile?,
			WaitForPlayerProfile: (self: unknown, player: Player) -> Promise.TypedPromise<ServerPlayerProfile>,
			GetPlayerProducerAsync: (
				self: unknown,
				player: Player
			) -> Promise.TypedPromise<ProfileTypes.PlayerProducer>,
			GetGameProducerAsync: (self: unknown) -> Promise.TypedPromise<gameProfile.Producer>,
		},
		[string]: unknown,
	},
	module: {
		[string]: unknown,
	},
	tag: {
		[string]: unknown,
	},
}

return table.freeze({})
