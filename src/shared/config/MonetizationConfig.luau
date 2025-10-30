export type DevProductSet = {
	{
		DevProductId: number,
		[string]: unknown,
	}
}

export type GamePassSet = {
	[string]: number,
}

export type MonetizationProduct = DevProductSet | GamePassSet

export type MonetizationConfig = {
	passes: GamePassSet,
	[string]: MonetizationProduct,
}

local MonetizationConfig: MonetizationConfig = {
	passes = {
		--
		["test"] = 0,
	},
}

return table.freeze(MonetizationConfig)
