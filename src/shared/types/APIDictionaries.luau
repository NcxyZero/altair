--[[
	```luau
	Dictionary returned by os.time("*t") and os.time("!*t")
	```

	@param year	int	An integer that describes the current year of the Current Era (ex. 2017)
	@param month	int	An integer between 1 and 12 (starting from January) that describes the current month.
	@param wday	int		An integer between 1 and 7 (starting from Sunday) that describes the current week day.
	@param yday	int	An integer between 1 and 366 describing how many days we are into the year. There can be 366 days if it is a leap year.
	@param day	int	An integer between 1 and 31 describing the current day of the month.
	@param hour	int	An integer between 1 and 24 describing the current hour of the day.
	@param min	int	An integer between 0 and 59 describing the current minute of the hour.
	@param sec	int	An integer between 0 and 60 describing the current second of the hour. (60 because the function is described to indicate leap seconds, but in practice it probably doesn't).
	@param isdst	boolean	A boolean describing if daylight savings time is currently active.
]]
export type DateDictionary = {
	year: number,
	month: number,
	wday: number,
	yday: number,
	day: number,
	hour: number,
	min: number,
	sec: number,
	isdst: boolean,
}

--[[
	```luau
	Dictionary of a MarketplaceService.ProcessReceipt callback
	```

	@param PurchaseId — A unique identifier for the specific purchase.
	@param PlayerId — The user ID of the user who made the purchase.
	@param ProductId — The ID of the purchased product.
	@param PlaceIdWherePurchased — The place ID in which the purchase was made. Depending on where the user is during gameplay, the purchase place's ID can be the same as or different from the current place's ID.
	@param CurrencySpent — The amount of currency spent in the transaction.
	@param CurrencyType — The type of currency spent in the purchase; always Enum.CurrencyType.Robux.
	@param ProductPurchaseChannel — How the user acquired the developer product. One of Enum.ProductPurchaseChannel.
]]
export type receiptInfo = {
	PurchaseId: number,
	PlayerId: number,
	ProductId: number,
	PlaceIdWherePurchased: number,
	CurrencySpent: number,
	CurrencyType: Enum.CurrencyType,
	ProductPurchaseChannel: Enum.ProductPurchaseChannel,
}

--[[
	```luau
	Dictionary returned by DateTime.ToUniversalTime() and DateTime.ToLocalTime()
	```

	@param Year	number	Range: 1400–9999
	@param Month	number	Range: 1–12
	@param Day	number	Range: 1–31
	@param Hour	number	Range: 0–23
	@param Minute	number	Range: 0–59
	@param Second	number	Range: 0–60,  Notes: Usually 0–59, sometimes 60 to accommodate leap seconds in certain systems.
	@param Millisecond	number	Range: 0–999
]]
export type TimeValues = {
	Year: number,
	Month: number,
	Day: number,
	Hour: number,
	Minute: number,
	Second: number,
	Millisecond: number,
}

return table.freeze({})
