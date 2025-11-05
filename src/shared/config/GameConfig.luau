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
		monetizationOfferCreationAllowed: boolean,
		playerCollisionsDisabled: boolean,
		raycastDetectionTimeout: number,
		resetButtonDisabled: boolean,
	},
	data: {
		datastoreKey: string,
		playerKeyPattern: string,
		playerProfileInvokeTimeout: number,
	},
	debug: {
		loggerShowInGame: boolean,
		loggerShowInStudio: boolean,
		onScreenOutputMaxLines: number, --tbd
		onScreenOutputMinRole: string, --tbd
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
		monetizationOfferCreationAllowed = false,
		playerCollisionsDisabled = true,
		raycastDetectionTimeout = 0.1,
		resetButtonDisabled = false,
	},
	data = {
		datastoreKey = "DEV1",
		playerKeyPattern = "%d",
		playerProfileInvokeTimeout = 30,
	},
	debug = {
		loggerShowInGame = false,
		loggerShowInStudio = true,
		onScreenOutputMaxLines = 5, --tbd
		onScreenOutputMinRole = "admin", --tbd
	},
	game = {
		--
	},
	roles = {
		admin = {
			rank = 200,
		},
	},
}

return table.freeze(gameConfig)
