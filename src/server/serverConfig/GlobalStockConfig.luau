export type StockItemConfig = {
	name: string,
	chance: number?,
	minAmount: number?,
	maxAmount: number?,
}

export type CoreSettings = {
	keyLength: number,
	maxUpdateAttempts: number,
}

export type DebugSettings = {
	enabled: boolean,
	forcedLogLimit: number,
}

export type SeedSettings = {
	zeroFallback: number,
	initialZero: number,
	fallbackOffset1: number,
	fallbackOffset2: number,
	countOffset: number,
}

export type StoreSettings = {
	keyDataStoreName: string,
	keyDataStoreKey: string,
	restockAnchorStore: string,
	forcedStockKey: string,
}

export type StockSettings = {
	core: CoreSettings,
	debug: DebugSettings,
	seed: SeedSettings,
	stores: StoreSettings,
}

export type StockOverrides = {
	core: CoreSettings?,
	debug: DebugSettings?,
	seed: SeedSettings?,
	stores: StoreSettings?,
}

export type StockDefinition = {
	name: string?,
	minItems: number,
	maxItems: number,
	restockInterval: number,
	timerAt: number?,
	timerInterval: number?,
	items: { StockItemConfig },
	info: { [string]: any }?,

	core: CoreSettings?,
	debug: DebugSettings?,
	seed: SeedSettings?,
	stores: StoreSettings?,
}

export type GlobalStockConfig = {
	defaults: StockSettings,

	stocks: { [string]: StockDefinition }?,
}

local globalStockConfig: GlobalStockConfig = {
	defaults = {
		core = {
			keyLength = 16,
			maxUpdateAttempts = 5,
		},
		debug = {
			enabled = false,
			forcedLogLimit = 5,
		},
		seed = {
			zeroFallback = 0xCAFEBABE,
			initialZero = 0xDEADBEEF,
			fallbackOffset1 = 99999,
			fallbackOffset2 = 88888,
			countOffset = 10000,
		},
		stores = {
			keyDataStoreName = "GlobalStockKeyStore",
			keyDataStoreKey = "GlobalStockKey_v1",
			restockAnchorStore = "GlobalRestockAnchor",
			forcedStockKey = "ForcedNextStock",
		},
	},

	stocks = {
		-- optional stock for a GameConfig.game.limitedItems entry (add a GameConfig require first);
		-- LimitedStockController reads only GameConfig.game.limitedItems and does not need this stock
		-- [GameConfig.game.limitedItems.Test1.stockName] = {
		-- 	minItems = 1,
		-- 	maxItems = 1,
		-- 	restockInterval = 0,
		-- 	items = {
		-- 		{
		-- 			name = GameConfig.game.limitedItems.Test1.itemKey,
		-- 			chance = 100,
		-- 			minAmount = GameConfig.game.limitedItems.Test1.amount,
		-- 			maxAmount = GameConfig.game.limitedItems.Test1.amount,
		-- 		},
		-- 	},
		-- },
	},
}

return table.freeze(globalStockConfig)
