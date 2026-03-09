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
	Dictionary returned by Player:GetJoinData() and used as parameter at TeleportOptions:SetJoinData()
	```

	@param SourceGameId	number	The `DataModel.GameId` of the experience the `Player` teleported from. Only present if the player teleports to the current experience and if a server calls the teleport function.
	@param SourcePlaceId	number		The `DataModel.PlaceId` of the place the `Player` teleported from. Only present if the player teleports to the current place and a server calls the teleport function.
	@param ReferredByPlayerId	number	The `UserId` of the player who invited the current player to the experience. Use this data to identify the referrer and trigger reward logic.
	@param Members	{ number }		An array containing the `UserId` numbers of the users teleported alongside the player. Only present if the player teleported as part of a group.
	@param TeleportData	{ [any]: any }	Reflects the `teleportData` specified in the original teleport. Useful for sharing information between servers the player teleports to. Only present if `teleportData` was specified and a server calls the teleport function.
	@param LaunchData	string	A plain or JSON encoded string that contains launch data specified in a `share link` or `ExperienceInviteOptions.LaunchData`.
	@param GameJoinContext	Dictionary	A dictionary that includes relevant information based on the context of the join. It contains the following keys: JoinSource: Enum.JoinSource, ItemType: optional Enum.AvatarItemType, AssetId: optional string, OutfitId: optional string, AssetType: optional Enum.AssetType
]]
export type GetJoinData = {
	SourceGameId: number,
	SourcePlaceId: number,
	ReferredByPlayerId: number,
	Members: { number },
	TeleportData: { [any]: any },
	LaunchData: string,
	GameJoinContext: {
		JoinSource: Enum.JoinSource,
		ItemType: Enum.AvatarItemType?,
		AssetId: string?,
		OutfitId: string?,
		AssetType: Enum.AssetType?,
	},
}

--[[
	```luau
	Dictionary parameter of a HttpService:RequestAsync()
	```

	@param Url	string	The target URL for this request. Must use `http` or `https` protocols.
	@param Method	string?	The HTTP method being used by this request, most often `GET` or `POST`.
	@param Headers	{ [string]: string }?	A dictionary of headers to be used with this request. Most HTTP headers are accepted here, but not all.
	@param Body	string?		The request body. Can be any string, including binary data. Must be excluded when using the `GET` or `HEAD` HTTP methods. It might be necessary to specify the `Content-Type` header when sending JSON or other formats.
	@param Compress	Enum.HttpCompression?	An optional compression field that will compress the data in the request. The value can either be `Enum.HttpCompression.None` or `Enum.HttpCompression.Gzip`.
]]
export type HttpRequestOptions = {
	Url: string,
	Method: string?,
	Headers: { [string]: string }?,
	Body: string?,
	Compress: Enum.HttpCompression?,
}

--[[
	```luau
	Dictionary returned by HttpService:RequestAsync()
	```

	@param Success	boolean	Indicates whether the HTTP request was successful.
	@param StatusCode	integer	The HTTP status code returned by the server (e.g., 200 for success, 404 for not found).
	@param StatusMessage	string	A message associated with the HTTP status code.
	@param Headers	{ [string]: string }	A dictionary of HTTP headers returned in the response.
	@param Body	{ [any]: any }	The body content of the HTTP response, typically as a string or parsed data.
]]
export type HttpResponseData = {
	Success: boolean,
	StatusCode: number,
	StatusMessage: string,
	Headers: { [string]: string },
	Body: { [any]: any },
}

--[[
	```luau
	Dictionary returned by MarketplaceService:GetDeveloperProductsAsync():GetCurrentPage()
	```

	@param Name	string	The name shown on the developer product's page.
	@param Description	string?	The description shown on the developer product's page; can be nil if blank.
	@param PriceInRobux	number	The cost of purchasing the developer product using Robux.
	@param ProductId	number	The product ID.
	@param IconImageAssetId	number	The asset ID of the product's icon, or 0 if there isn't one.
]]
export type MarketplaceDeveloperProductInfo = {
	Name: string,
	Description: string?,
	PriceInRobux: number,
	ProductId: number,
	IconImageAssetId: number,
}

--[[
	```luau
	Dictionary returned by MarketplaceService:GetProductInfoAsync()
	```

	@param Name	string	The name shown on the asset's page.
	@param Description	string?	The description shown on the asset's page; can be nil if blank.
	@param PriceInRobux	number?	The cost of purchasing the asset using Robux.
	@param ProductId	number?	The product ID if Enum.InfoType is Product.
	@param ProductType	string?	A string describing what the product is. Not to be confused with Enum.MarketplaceProductType.
	@param Created	string?	Timestamp of when the asset was created, for example 2022-01-02T10:30:45Z. Formatted using ISO 8601.
	@param Updated	string?	Timestamp of when the asset was last updated by its creator, for example 2022-02-12T11:22:15Z. Formatted using ISO 8601.
	@param ContentRatingTypeId	number?	Indicates whether the item is marked as 13+ in catalog.
	@param MinimumMembershipLevel	number?	The minimum subscription level necessary to purchase the item.
	@param IsPublicDomain	boolean?	Describes whether the asset can be taken for free.
	@param TargetId	number?	The ID of the product or asset.
	@param Creator	MarketplaceProductInfoCreator?	Dictionary table of information describing the creator of the asset.
	@param AssetId	number?	The asset ID if Enum.InfoType is Asset.
	@param AssetTypeId	number?	The type of asset. See Enum.AssetType for the asset type ID numbers.
	@param IconImageAssetId	number?	The asset ID of the product's icon, or 0 if there isn't one.
	@param IsForSale	boolean?	Describes whether the asset is purchasable.
	@param IsLimited	boolean?	Describes whether the asset is a Roblox Limited that is no longer (if ever) sold.
	@param IsLimitedUnique	boolean?	Describes whether the asset is a unique Roblox Limited ("Limited U") item that only has a fixed number sold.
	@param IsNew	boolean?	Describes whether the asset is marked as "new" in the catalog.
	@param Remaining	number?	The remaining number of times a limited unique item may be sold.
	@param Sales	number?	The number of times the asset has been sold.
	@param CollectibleItemId	string?	The unique item ID of the collectible.
	@param CollectibleProductId	string?	The unique product ID of the collectible.
	@param CollectiblesItemDetails	MarketplaceProductInfoCollectiblesItemDetails?	Dictionary table of information describing the collectible.
	@param CanBeSoldInThisGame	boolean?	Describes whether the asset is purchasable in the current experience.
	@param SaleLocation	MarketplaceProductInfoSaleLocation?	Dictionary table of information describing where the item can be sold.
]]
export type MarketplaceProductInfo = {
	Name: string,
	Description: string?,
	PriceInRobux: number?,
	ProductId: number?,
	ProductType: string?,
	Created: string?,
	Updated: string?,
	ContentRatingTypeId: number?,
	MinimumMembershipLevel: number?,
	IsPublicDomain: boolean?,
	TargetId: number?,
	Creator: MarketplaceProductInfoCreator?,
	AssetId: number?,
	AssetTypeId: number?,
	IconImageAssetId: number?,
	IsForSale: boolean?,
	IsLimited: boolean?,
	IsLimitedUnique: boolean?,
	IsNew: boolean?,
	Remaining: number?,
	Sales: number?,
	CollectibleItemId: string?,
	CollectibleProductId: string?,
	CollectiblesItemDetails: MarketplaceProductInfoCollectiblesItemDetails?,
	CanBeSoldInThisGame: boolean?,
	SaleLocation: MarketplaceProductInfoSaleLocation?,
}

--[[
	```luau
	CollectiblesItemDetails dictionary returned inside MarketplaceService:GetProductInfoAsync()
	```

	@param CollectibleLowestAvailableResaleItemInstanceId	string	The unique item instance ID of the lowest available resale for the collectible.
	@param CollectibleLowestAvailableResaleProductId	string	The unique product ID of the lowest available resale for the collectible.
	@param CollectibleLowestResalePrice	number	The lowest resale price for the collectible in Robux.
	@param IsForSale	boolean	Boolean of whether the collectible is available for sale (not resale).
	@param IsLimited	boolean	Boolean of whether or not the collectible is limited.
	@param TotalQuantity	number	The total quantity of the collectible available for purchase (not resale).
]]
export type MarketplaceProductInfoCollectiblesItemDetails = {
	CollectibleLowestAvailableResaleItemInstanceId: string,
	CollectibleLowestAvailableResaleProductId: string,
	CollectibleLowestResalePrice: number,
	IsForSale: boolean,
	IsLimited: boolean,
	TotalQuantity: number,
}

--[[
	```luau
	Creator dictionary returned inside MarketplaceService:GetProductInfoAsync()
	```

	@param CreatorType	"User" | "Group"	Either User or Group.
	@param CreatorTargetId	number	The ID of the creator user or group.
	@param HasVerifiedBadge	boolean	Boolean of whether the creator has a verified badge.
	@param Name	string	The name/username of the creator.
	@param Id	number?	Use CreatorTargetId instead.
	]]
export type MarketplaceProductInfoCreator = {
	CreatorType: "User" | "Group",
	CreatorTargetId: number,
	HasVerifiedBadge: boolean,
	Name: string,
	Id: number?,
}

--[[
	```luau
	SaleLocation dictionary returned inside MarketplaceService:GetProductInfoAsync()
	```

	@param SaleLocationType	Enum.ProductLocationRestriction	The type of sale location setting. See Enum.ProductLocationRestriction for the sale location setting ID numbers.
	@param UniverseIds	{ number }	Array table of universes in which the item can be sold (not currently implemented).
]]
export type MarketplaceProductInfoSaleLocation = {
	SaleLocationType: Enum.ProductLocationRestriction,
	UniverseIds: { number },
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
