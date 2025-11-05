export type GamePassSet = {
	[string]: number,
}

export type DevProductSet = {
	[string]: DevProduct,
}

export type DevProductData = number | Data | { data: { [any]: Data } }

export type DevProduct =
	DevProductData
	& ({
		exec: Exec? | { Exec }?,
	} | {
		execs: Exec? | { Exec }?,
	})
	& ({
		offer: string? | { string }?,
	} | {
		offers: string? | { string }?,
	})

export type Data = {
	id: number,
	[any]: any?,
}

export type Exec = string | (...any) -> () | {
	name: string?,
	func: (...any) -> ()?,
	value: any?,
}

export type MonetizationProduct = DevProductSet | GamePassSet

export type MonetizationConfig = {
	passes: GamePassSet,
	products: DevProductSet,
}

local MonetizationConfig: MonetizationConfig = {
	passes = {
		--
		Test = 1234,
	},
	products = {
		Test1 = 1234,

		Test2 = {
			id = 12345,
		},

		Test3 = {
			data = {
				Variant1 = {
					id = 123456,
					money = 150,
				},
				Variant2 = {
					id = 1234567,
					money = 350,
					bonus = true,
				},
			},
			execs = {
				"Exec1",
				"NonExistantExecTest",
				function() end,
			},
			offer = "Offer1",
		},
	},
}

return table.freeze(MonetizationConfig)
