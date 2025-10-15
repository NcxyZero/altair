export type GameConfig = {
	cmdr: {
		activationKeys: { Enum.KeyCode },
		cacheRefreshTime: number,
		role: string,
	},
	core: {
		cacheErrorMaxRetries: number,
		cacheErrorTimeout: number,
		cacheTimeout: number,
		playerCollisionsDisable: boolean,
		resetButtonDisable: boolean,
	},
	game: {
		--
	},
	roles: {
		[string]: {
			rank: number,
			groupId: number?,
		},
	},
}

local gameConfig: GameConfig = {
	cmdr = {
		activationKeys = {
			Enum.KeyCode.F2,
		},
		cacheRefreshTime = 30,
		role = "admin",
	},
	core = {
		cacheErrorMaxRetries = 5,
		cacheErrorTimeout = 1.5,
		cacheTimeout = 15,
		playerCollisionsDisable = true,
		resetButtonDisable = true,
	},
	game = {},
	roles = {
		admin = {
			rank = 200,
		},
	},
}

return table.freeze(gameConfig)
