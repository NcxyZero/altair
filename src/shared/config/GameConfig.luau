export type GameConfig = {
	cmdr: {
		activationKeys: { Enum.KeyCode },
		cacheRefreshTime: number,
		role: string,
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
	roles = {
		admin = {
			rank = 200,
		},
	},
}

return table.freeze(gameConfig)
