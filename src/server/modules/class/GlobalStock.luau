local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BuildStockConfigUtil = require(ReplicatedStorage.util.BuildStockConfig)
local GlobalStockConfig = require(ServerScriptService.server.serverConfig.GlobalStockConfig)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Logger)
local Maid = require(ReplicatedStorage.package.Maid)

export type StockItem = {
	name: string,
	chance: number?,
	minAmount: number?,
	maxAmount: number?,
}

export type StockData = {
	stockItems: { StockItem },
	minItems: number,
	maxItems: number,
	restockInterval: number,
	globalKey: { number }?,
	currentStock: { any },
	running: boolean,
	stockName: string,
	allowedDays: { [number]: boolean }?,
	dateStart: number?,
	dateEnd: number?,
	config: GlobalStockConfig.StockSettings,
}

export type Default = {
	__index: Default,
	type: string,
	path: InitializerTypes.ServerPath,
	maid: Maid.Maid,
	config: GlobalStockConfig.GlobalStockConfig,
	debug: boolean,
	forcedLogLimit: number,
	cachedGlobalKeyByStock: { [string]: { number } },
	fetchingGlobalKeyByStock: { [string]: boolean },
	cachedAnchorKeyByStock: { [string]: number },
	stocks: { [string]: StockData },
	new: (config: GlobalStockConfig.GlobalStockConfig?) -> Default,
	Rol32: (self: Default, value: number, shift: number) -> number,
	MakeXorShift32: (self: Default, seed: number, initialZero: number) -> () -> number,
	GenerateRandomKey: (self: Default, keyLength: number) -> { number },
	KeyAndTimeToSeed: (self: Default, keyNumbers: { number }, restockTime: number, zeroFallback: number) -> number,
	ComputeDeterministicBoundary: (self: Default, anchor: number, stockName: string, interval: number) -> number,
	ToTime: (self: Default, dateTable: { number }?) -> number?,
	IsDayAllowed: (self: Default, allowedDays: { [number]: boolean }?, now: number) -> boolean,
	InDateRange: (self: Default, startTimestamp: number?, endTimestamp: number?, now: number) -> boolean,
	PredictStock: (self: Default, stockData: StockData, restockTime: number) -> { any },
	GetKeyStore: (self: Default, stockName: string) -> GlobalDataStore,
	GetOrCreateGlobalKeyFromDataStore: (self: Default, stockName: string) -> { number }?,
	EnsureGlobalKeyAsync: (self: Default, stockName: string) -> { number }?,
	GetAnchor: (self: Default, stockName: string) -> number,
	MemoryStoreMap: (self: Default, stockName: string) -> MemoryStoreSortedMap,
	GetForcedStock: (self: Default, stockName: string) -> { any }?,
	SaveForcedStock: (self: Default, stockName: string, stockList: { any }, restocks: number) -> (),
	ClearForcedStockInStore: (self: Default, stockName: string) -> (),
	CreateStock: (
		self: Default,
		stockName: string,
		stockItems: { StockItem },
		minItems: number,
		maxItems: number,
		restockInterval: number,
		info: { start: { number }?, [string]: any }?,
		stockConfig: GlobalStockConfig.StockSettings?
	) -> StockData?,
	GetCurrentStock: (self: Default, stockName: string) -> { any }?,
	GetStockForRestockTime: (self: Default, stockName: string, restockTime: number) -> { any }?,
	GetDeterministicBoundary: (self: Default, stockName: string) -> number?,
	GetNextRestockTime: (self: Default, stockName: string) -> number?,
	GetTimeUntilRestock: (self: Default, stockName: string) -> number?,
	ForceNextStock: (self: Default, stockName: string, stockList: { any }, restocks: number?) -> boolean,
	ClearForcedStock: (self: Default, stockName: string) -> (),
	StopStock: (self: Default, stockName: string) -> (),
	SetDebug: (self: Default, enabled: boolean) -> (),
	GetStockConfig: (self: Default, stockName: string) -> GlobalStockConfig.StockSettings,
}

local GlobalStock: Default = {} :: any
GlobalStock.__index = GlobalStock
GlobalStock.type = "other"

local function buildStockConfig(
	defaults: GlobalStockConfig.StockSettings,
	overrides: { [string]: any }?
): GlobalStockConfig.StockSettings
	return BuildStockConfigUtil(defaults, overrides) :: any
end

function GlobalStock:Rol32(value: number, shift: number): number
	shift %= 32

	local left: number = bit32.lshift(value, shift)
	local right: number = bit32.rshift(value, 32 - shift)

	return bit32.band(bit32.bor(left, right), 0xFFFFFFFF)
end

function GlobalStock:MakeXorShift32(seed: number, initialZero: number): () -> number
	local seedState: number = bit32.band(tonumber(seed) or 0, 0xFFFFFFFF)
	seedState = seedState == 0 and bit32.band(tonumber(initialZero) or 1, 0xFFFFFFFF) or seedState

	return function(): number
		seedState = bit32.bxor(seedState, bit32.lshift(seedState, 13))
		seedState = bit32.bxor(seedState, bit32.rshift(seedState, 17))
		seedState = bit32.bxor(seedState, bit32.lshift(seedState, 5))
		seedState = bit32.band(seedState, 0xFFFFFFFF)

		return seedState / 0x100000000
	end
end

function GlobalStock:GenerateRandomKey(keyLength: number): { number }
	local randomGenerator: Random = Random.new()
	local keyNumbers: { number } = {}

	for index: number = 1, keyLength do
		keyNumbers[index] = randomGenerator:NextInteger(0, 0x7FFFFFFF)
	end

	return keyNumbers
end

function GlobalStock:KeyAndTimeToSeed(keyNumbers: { number }, restockTime: number, zeroFallback: number): number
	local seed: number = bit32.band(tonumber(restockTime) or os.time(), 0xFFFFFFFF)

	for index: number = 1, #keyNumbers do
		local numberValue: number = keyNumbers[index] or 0
		local rotated: number = self:Rol32(bit32.band(numberValue, 0xFFFFFFFF), index)
		seed = bit32.bxor(seed, rotated)
		seed = bit32.band(seed + (numberValue % 0x100000000), 0xFFFFFFFF)
	end

	return seed == 0 and zeroFallback or seed
end

function GlobalStock:ComputeDeterministicBoundary(anchor: number, stockName: string, interval: number): number
	local hash: number = 0
	for charIndex: number = 1, #stockName do
		hash = (hash + stockName:byte(charIndex)) % interval
	end

	local now: number = os.time()
	return now - ((now - (anchor + hash)) % interval)
end

function GlobalStock.new(config: typeof(GlobalStockConfig)?): Default
	local self = setmetatable({}, GlobalStock)

	self.maid = Maid.new()
	self.config = config or GlobalStockConfig
	self.debug = self.config.defaults.debug.enabled
	self.forcedLogLimit = self.config.defaults.debug.forcedLogLimit
	self.cachedGlobalKeyByStock = {}
	self.fetchingGlobalKeyByStock = {}
	self.cachedAnchorKeyByStock = {}
	self.stocks = {}

	if self.config.stocks then
		for stockName: string, definition in self.config.stocks do
			local nameToUse: string = definition.name or stockName
			local mergedConfig = buildStockConfig(self.config.defaults, definition)

			self:CreateStock(
				nameToUse,
				definition.items,
				definition.minItems,
				definition.maxItems,
				definition.restockInterval,
				definition.info,
				mergedConfig
			)
		end
	end

	return self
end

function GlobalStock:SetDebug(enabled: boolean): ()
	self.debug = enabled
end

function GlobalStock:GetStockConfig(stockName: string): typeof(GlobalStockConfig.defaults)
	local stockData = self.stocks[stockName]
	local config: GlobalStockConfig.StockSettings = self.config.defaults

	if stockData then
		config = stockData.config
	end

	return config
end

function GlobalStock:GetKeyStore(stockName: string): GlobalDataStore
	local config: GlobalStockConfig.StockSettings = self:GetStockConfig(stockName)
	local storeName: string = config.stores.keyDataStoreName

	return DataStoreService:GetDataStore(storeName)
end

function GlobalStock:GetOrCreateGlobalKeyFromDataStore(stockName: string): { number }?
	if self.cachedGlobalKeyByStock[stockName] then
		local sd: StockData = self.stocks[stockName]
		if sd and not sd.globalKey then
			sd.globalKey = self.cachedGlobalKeyByStock[stockName]
		end

		return self.cachedGlobalKeyByStock[stockName]
	end

	if self.fetchingGlobalKeyByStock[stockName] then
		return
	end
	self.fetchingGlobalKeyByStock[stockName] = true

	local store: GlobalDataStore = self:GetKeyStore(stockName)
	local cfg: GlobalStockConfig.StockSettings = self:GetStockConfig(stockName)
	local keyKey: string = cfg.stores.keyDataStoreKey
	local attempts: number = cfg.core.maxUpdateAttempts

	for attempt = 1, attempts do
		local success: boolean, result: any = pcall(function(): any
			return store:UpdateAsync(keyKey, function(oldValue: any): (any, { number }?, {}?)
				if oldValue and type(oldValue) == "table" and oldValue.numbers then
					return oldValue
				end

				return {
					numbers = self:GenerateRandomKey(cfg.core.keyLength),
					created = os.time(),
				}
			end)
		end)

		if success and type(result) == "table" and result.numbers then
			self.cachedGlobalKeyByStock[stockName] = result.numbers
			self.fetchingGlobalKeyByStock[stockName] = false

			local sd: StockData = self.stocks[stockName]
			if sd then
				sd.globalKey = result.numbers
			end

			return self.cachedGlobalKeyByStock[stockName]
		end

		task.wait(math.min(attempt, 5))
	end

	self.fetchingGlobalKeyByStock[stockName] = false

	Logger.warn(`Failed to fetch global key for stock "{stockName}" after {attempts} attempts`)

	return
end

function GlobalStock:EnsureGlobalKeyAsync(stockName: string): { number }?
	if self.cachedGlobalKeyByStock[stockName] then
		local sd: StockData = self.stocks[stockName]
		if sd and not sd.globalKey then
			sd.globalKey = self.cachedGlobalKeyByStock[stockName]
		end

		return self.cachedGlobalKeyByStock[stockName]
	end

	local key: { number }? = self:GetOrCreateGlobalKeyFromDataStore(stockName)
	if key then
		return key
	end

	task.delay(5, function(): ()
		self:GetOrCreateGlobalKeyFromDataStore(stockName)
	end)

	return
end

function GlobalStock:GetAnchor(stockName: string): number
	local cached: number = self.cachedAnchorKeyByStock[stockName]
	if cached ~= nil then
		return cached
	end

	local config: GlobalStockConfig.StockSettings = self:GetStockConfig(stockName)
	local anchorStoreName: string = config.stores.restockAnchorStore
	local restockAnchorStore: DataStore = DataStoreService:GetDataStore(anchorStoreName)

	local success: boolean, stored: any = pcall(function(): any
		return restockAnchorStore:UpdateAsync("Anchor", function(oldValue: any): (any, { number }?, {}?)
			if type(oldValue) == "number" then
				return oldValue - (oldValue % 5)
			end

			local now: number = os.time()

			return now - (now % 5)
		end)
	end)

	if success and type(stored) == "number" then
		self.cachedAnchorKeyByStock[stockName] = stored

		return stored
	end

	local now: number = os.time()
	local fallbackAnchor: number = now - (now % 5)

	xpcall(function(): ()
		self.cachedAnchorKeyByStock[stockName] = fallbackAnchor
		restockAnchorStore:SetAsync("Anchor", fallbackAnchor)
	end, Logger.warn)

	return fallbackAnchor
end

function GlobalStock:MemoryStoreMap(stockName: string): MemoryStoreSortedMap
	local config: GlobalStockConfig.StockSettings = self:GetStockConfig(stockName)
	local key: string = config.stores.forcedStockKey

	return MemoryStoreService:GetSortedMap(key)
end

function GlobalStock:GetForcedStock(stockName: string): { any }?
	local memoryStoreMap: MemoryStoreSortedMap = self:MemoryStoreMap(stockName)

	local success: boolean, forcedStock: any = xpcall(function(): any
		return memoryStoreMap:GetAsync(stockName)
	end, Logger.warn)

	if success and type(forcedStock) == "table" then
		return forcedStock
	end

	return
end

function GlobalStock:SaveForcedStock(stockName: string, stockList: { any }, restocks: number): ()
	local memoryStoreMap: MemoryStoreSortedMap = self:MemoryStoreMap(stockName)

	local expiration: number = tonumber(restocks) or 1
	local stockData = self.stocks[stockName]
	local interval: number = stockData and stockData.restockInterval or 600
	expiration *= interval

	xpcall(function(): ()
		memoryStoreMap:SetAsync(stockName, stockList, expiration)
	end, Logger.warn)
end

function GlobalStock:ClearForcedStockInStore(stockName: string): ()
	local memoryStoreMap: MemoryStoreSortedMap = self:MemoryStoreMap(stockName)

	xpcall(function(): ()
		memoryStoreMap:RemoveAsync(stockName)
	end, Logger.warn)
end

function GlobalStock:ToTime(dateTable: { number }?): number?
	if not dateTable then
		return
	end

	local year: number = dateTable[1]
	local month: number = dateTable[2]
	local day: number = dateTable[3]

	if type(year) ~= "number" or type(month) ~= "number" or type(day) ~= "number" then
		return
	end

	return os.time({ year = year, month = month, day = day, hour = 0, min = 0, sec = 0 })
end

function GlobalStock:IsDayAllowed(allowedDays: { [number]: boolean }?, now: number): boolean
	if not allowedDays then
		return true
	end

	local dayNumberString: string = os.date("!%w", now)
	local dayId: number? = tonumber(dayNumberString)
	if not dayId then
		return false
	end

	dayId += 1

	return allowedDays[dayId] == true
end

function GlobalStock:InDateRange(startTimestamp: number?, endTimestamp: number?, now: number): boolean
	if not startTimestamp and not endTimestamp then
		return true
	end

	local startValue: number = startTimestamp or 0
	local endValue: number = endTimestamp or 9e9

	return now >= startValue and now <= endValue
end

function GlobalStock:PredictStock(stockData: StockData, restockTime: number): { any }
	assert(stockData.globalKey and type(stockData.globalKey) == "table", "Global key not set")

	local seed: number = self:KeyAndTimeToSeed(stockData.globalKey, restockTime, stockData.config.seed.zeroFallback)
	local random: () -> number = self:MakeXorShift32(seed, stockData.config.seed.initialZero)

	local candidates: { { amount: number, name: string } } = {} :: any
	for _index: number, itemData: StockItem in ipairs(stockData.stockItems) do
		if type(itemData) ~= "table" then
			continue
		end

		local itemName: string = itemData.name
		if type(itemName) ~= "string" then
			continue
		end

		local chance: number = math.clamp(tonumber(itemData.chance) or 100, 0, 100)
		local minAmount: number = math.max(1, tonumber(itemData.minAmount) or 1)
		local maxAmount: number = math.max(minAmount, tonumber(itemData.maxAmount) or minAmount)

		if random() > (chance / 100) then
			continue
		end

		local amount: number = minAmount
		if maxAmount > minAmount then
			local amountRandom = self:MakeXorShift32(seed + (#candidates + 1), stockData.config.seed.initialZero)
			amount = minAmount + (amountRandom() * (maxAmount - minAmount + 1)) // 1
			amount = math.min(amount, maxAmount)
		end

		table.insert(candidates, { name = itemName, amount = amount })
	end

	if #candidates < stockData.minItems then
		local missing: number = stockData.minItems - #candidates
		local pool: { StockItem } = {}

		for _index: number, item: StockItem in ipairs(stockData.stockItems) do
			local alreadyIn: boolean = false
			for _index: number, candidate: { amount: number, name: string } in candidates do
				if candidate.name == item.name then
					alreadyIn = true

					break
				end
			end

			if alreadyIn then
				continue
			end

			table.insert(pool, item)
		end

		local fillerRandom: () -> number = self:MakeXorShift32(seed + 123456, stockData.config.seed.initialZero)
		for _index = 1, missing do
			if #pool == 0 then
				break
			end

			local index: number = 1 + (fillerRandom() * #pool) // 1
			local item: StockItem = table.remove(pool, index) :: any
			local minAmount: number = math.max(1, tonumber(item.minAmount) or 1)
			local maxAmount: number = math.max(minAmount, tonumber(item.maxAmount) or minAmount)
			local amount: number = minAmount

			if maxAmount > minAmount then
				amount = minAmount + (fillerRandom() * (maxAmount - minAmount + 1)) // 1
				amount = math.min(amount, maxAmount)
			end

			table.insert(candidates, { name = item.name, amount = amount })
		end
	end

	for index: number = #candidates, 2, -1 do
		local swapIndex = 1 + (random() * index) // 1
		candidates[index], candidates[swapIndex] = candidates[swapIndex], candidates[index]
	end

	local minCount: number = stockData.minItems
	local maxCount: number = math.min(stockData.maxItems, #candidates)

	local countToReturn: number = minCount
	if maxCount > minCount then
		local randomCount: () -> number =
			self:MakeXorShift32(seed + stockData.config.seed.countOffset, stockData.config.seed.initialZero)
		countToReturn = minCount + (randomCount() * (maxCount - minCount + 1)) // 1
	end

	local predictedStock: { { amount: number, name: string } } = {}
	for listIndex = 1, countToReturn do
		table.insert(predictedStock, candidates[listIndex])
	end

	return predictedStock
end

function GlobalStock:CreateStock(
	stockName: string,
	stockItems: { StockItem },
	minItems: number,
	maxItems: number,
	restockInterval: number,
	info: { start: { number }?, [string]: any }?,
	stockConfig: GlobalStockConfig.StockSettings?
): StockData?
	assert(type(stockName) == "string", "stockName must be string")
	assert(type(stockItems) == "table", "stockItems must be table")

	minItems = tonumber(minItems) or 1
	maxItems = tonumber(maxItems) or minItems
	restockInterval = tonumber(restockInterval) or 50

	if self.stocks[stockName] then
		Logger.warn(`Stock '{stockName}' already exists. Overwriting.`)
	end

	local mergedConfig: GlobalStockConfig.StockSettings = buildStockConfig(self.config.defaults, stockConfig)

	local stockData: StockData = {
		stockItems = stockItems,
		minItems = minItems,
		maxItems = maxItems,
		restockInterval = restockInterval,
		globalKey = nil,
		currentStock = {},
		running = true,
		stockName = stockName,
		config = mergedConfig,
	}

	if info then
		if info.start then
			stockData.dateStart = self:ToTime(info.start)
		end

		if info["end"] then
			stockData.dateEnd = self:ToTime(info["end"]) :: number
		end

		if info.days then
			stockData.allowedDays = {}

			for _index: number, dayValue in info.days do
				local lowerName: string = tostring(dayValue):lower()
				local dayId = ({
					sunday = 1,
					monday = 2,
					tuesday = 3,
					wednesday = 4,
					thursday = 5,
					friday = 6,
					saturday = 7,
				})[lowerName]

				if not dayId then
					continue
				end

				(stockData.allowedDays :: { boolean })[dayId] = true
			end
		end
	end

	self.stocks[stockName] = stockData
	stockData.globalKey = nil

	task.spawn(function(): ()
		self:EnsureGlobalKeyAsync(stockName)
	end)

	return stockData
end

function GlobalStock:GetDeterministicBoundary(stockName: string): number?
	local stockData = self.stocks[stockName]
	if not stockData then
		return
	end

	return self:ComputeDeterministicBoundary(self:GetAnchor(stockName), stockName, stockData.restockInterval)
end

function GlobalStock:GetNextRestockTime(stockName: string): number?
	local stockData = self.stocks[stockName]
	if not stockData then
		return
	end

	local boundary: number? = self:GetDeterministicBoundary(stockName)
	if not boundary then
		return
	end

	return boundary + stockData.restockInterval
end

function GlobalStock:GetTimeUntilRestock(stockName: string): number?
	local nextTime: number? = self:GetNextRestockTime(stockName)
	if not nextTime then
		return
	end

	return math.max(0, nextTime - os.time())
end

function GlobalStock:GetCurrentStock(stockName: string): { any }?
	local stockData = self.stocks[stockName]
	if not stockData then
		return {}
	end

	local forcedStock: { any }? = self:GetForcedStock(stockName)
	if forcedStock then
		return forcedStock
	end

	local anchor: number = self:GetAnchor(stockName)
	local restockTime: number = self:ComputeDeterministicBoundary(anchor, stockName, stockData.restockInterval)

	local now: number = os.time()
	local inWindow: boolean = self:InDateRange(stockData.dateStart, stockData.dateEnd, now)
		and self:IsDayAllowed(stockData.allowedDays, now)
	if not inWindow then
		return {}
	end

	if not stockData.globalKey then
		task.spawn(function(): ()
			self:EnsureGlobalKeyAsync(stockName)
		end)

		return {}
	end

	return self:PredictStock(stockData, restockTime)
end

function GlobalStock:GetStockForRestockTime(stockName: string, restockTime: number): { any }?
	local stockData = self.stocks[stockName]
	if not stockData then
		return {}
	end

	local forcedStock: { any }? = self:GetForcedStock(stockName)
	if forcedStock then
		return forcedStock
	end

	local inWindow: boolean = self:InDateRange(stockData.dateStart, stockData.dateEnd, restockTime)
		and self:IsDayAllowed(stockData.allowedDays, restockTime)
	if not inWindow then
		return {}
	end

	if not stockData.globalKey then
		task.spawn(function(): ()
			self:EnsureGlobalKeyAsync(stockName)
		end)

		return {}
	end

	local anchor: number = self:GetAnchor(stockName)
	local interval: number = stockData.restockInterval
	local boundaryNow: number = self:ComputeDeterministicBoundary(anchor, stockName, interval)
	local offsetIntervals: number = math.max(0, (restockTime - boundaryNow)) // interval
	local targetBoundary: number = boundaryNow + (offsetIntervals * interval)

	return self:PredictStock(stockData, targetBoundary)
end

function GlobalStock:ForceNextStock(stockName: string, stockList: { any }, restocks: number?): boolean
	assert(type(stockName) == "string", "stockName must be string")
	assert(type(stockList) == "table", "stockList must be table")

	local stockData = self.stocks[stockName]
	if not stockData then
		Logger.warn(`ForceNextStock failed: Stock '{stockName}' does not exist`)

		return false
	end

	self:SaveForcedStock(stockName, stockList, tonumber(restocks) or 1)

	stockData.currentStock = stockList

	return true
end

function GlobalStock:ClearForcedStock(stockName: string): ()
	self:ClearForcedStockInStore(stockName)
end

function GlobalStock:StopStock(stockName: string): ()
	local stockData = self.stocks[stockName]
	if not stockData then
		return
	end

	stockData.running = false
	self.stocks[stockName] = nil
end

return GlobalStock
