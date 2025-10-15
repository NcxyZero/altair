export type DevProductSet = {
	{
		DevProductId: number,
		[string]: unknown,
	}
}

export type GamePassSet = {
	[string]: number,
}

export type MonetizationConfig = {
	passes: GamePassSet,
	[string]: DevProductSet | GamePassSet,
}

local MonetizationConfig: MonetizationConfig = {
	passes = {
		--
		["test"] = 0,
	},
}

return table.freeze(MonetizationConfig)
