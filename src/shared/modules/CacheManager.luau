local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Logger)
local Promise = require(ReplicatedStorage.package.Promise)
local WithoutPlayer = require(ReplicatedStorage.util.WithoutPlayer)

export type CacheEntry = {
	value: any,
	expireAt: number,
}

export type CacheManagerServer = {
	Clear: (self: CacheManager, player: Player, key: string, category: string?) -> (),
	ClearAll: (self: CacheManager, player: Player, category: string?) -> (),
	Get: (self: CacheManager, player: Player, key: string, category: string?) -> any?,
	GetOrCompute: (
		self: CacheManager,
		player: Player,
		key: string,
		compute: () -> any,
		ttl: number?,
		category: string?
	) -> any?,
	Has: (self: CacheManager, player: Player, key: string, category: string?) -> boolean,
	PlayerRemoving: (self: CacheManager, player: Player) -> (),
	Set: (self: CacheManager, player: Player, key: string, value: any, ttl: number?, category: string?) -> (),
	caches: { [Player]: { [string]: { [string]: CacheEntry } } },
	path: InitializerTypes.ServerPath,
	defaultCategory: string,
}

export type CacheManagerClient = {
	Clear: (self: CacheManager, key: string, category: string?) -> (),
	ClearAll: (self: CacheManager, category: string?) -> (),
	Get: (self: CacheManager, key: string, category: string?) -> any?,
	GetOrCompute: (self: CacheManager, key: string, compute: () -> any, ttl: number?, category: string?) -> any?,
	Has: (self: CacheManager, key: string, category: string?) -> boolean,
	Set: (self: CacheManager, key: string, value: any, ttl: number?, category: string?) -> (),
	caches: { [string]: { [string]: CacheEntry } },
	path: InitializerTypes.ClientPath,
	defaultCategory: string,
}

export type CacheManager = CacheManagerServer & CacheManagerClient

type PendingComputations = { [string]: { [string]: Promise.TypedPromise<any> } }

type CacheMethods = {
	Clear: (self: CacheManager, player: Player?, key: string, category: string?) -> (),
	ClearAll: (self: CacheManager, player: Player?, category: string?) -> (),
	Get: (self: CacheManager, player: Player?, key: string, category: string?) -> any?,
	GetOrCompute: (
		self: CacheManager,
		player: Player?,
		key: string,
		compute: () -> any,
		ttl: number?,
		category: string?
	) -> any?,
	Has: (self: CacheManager, player: Player?, key: string, category: string?) -> boolean,
	Set: (self: CacheManager, player: Player?, key: string, value: any, ttl: number?, category: string?) -> (),
	defaultCategory: string,
	type: string,
}

local CacheMethods: CacheMethods = {
	type = "other",
	defaultCategory = "default",
} :: CacheMethods

local clientPendingComputations: PendingComputations = {}
local serverPendingComputations: { [Player]: PendingComputations } = {}

local function getTtl(ttl: number?): number
	local configured: number = GameConfig.core.cacheTimeout
	return ttl and ttl > 0 and ttl or configured
end

local function isExpired(entry: CacheEntry): boolean
	return os.clock() >= entry.expireAt
end

local function computeWithRetry(compute: () -> any): (boolean, any)
	local retries: number = 0

	repeat
		local ok: boolean, value: any = xpcall(function(): any
			return compute()
		end, Logger.warn)

		if ok then
			return true, value
		end

		retries += 1
		if retries < GameConfig.core.cacheErrorMaxRetries then
			task.wait(GameConfig.core.cacheErrorTimeout)
		end
	until retries >= GameConfig.core.cacheErrorMaxRetries

	return false, nil
end

local function getCategories(
	self: CacheManager,
	player: Player?,
	create: boolean
): { [string]: { [string]: CacheEntry } }?
	if not player then
		local client: CacheManagerClient = self

		return client.caches
	end

	local server: CacheManagerServer = self
	local categories: { [string]: { [string]: CacheEntry } } = server.caches[player]
	if not categories and create then
		categories = {}
		server.caches[player] = categories
	end

	return categories
end

local function getContainer(self: CacheManager, player: Player?, category: string?): { [string]: CacheEntry }
	local categories: { [string]: { [string]: CacheEntry } } =
		getCategories(self, player, true) :: { [string]: { [string]: CacheEntry } }
	local categoryName: string = category or self.defaultCategory
	local container: { [string]: CacheEntry } = categories[categoryName]
	if not container then
		container = {}
		categories[categoryName] = container
	end

	return container
end

local function getPendingComputations(player: Player?, create: boolean): PendingComputations?
	if not player then
		return clientPendingComputations
	end

	local pendingComputations: PendingComputations = serverPendingComputations[player]
	if not pendingComputations and create then
		pendingComputations = {}
		serverPendingComputations[player] = pendingComputations
	end

	return pendingComputations
end

local function getPendingContainer(
	self: CacheManager,
	player: Player?,
	category: string?,
	create: boolean
): { [string]: Promise.TypedPromise<any> }?
	local pendingComputations: PendingComputations = getPendingComputations(player, create) :: PendingComputations
	if not pendingComputations then
		return
	end

	local categoryName: string = category or self.defaultCategory
	local pendingContainer: { [string]: Promise.TypedPromise<any> } = pendingComputations[categoryName]
	if not pendingContainer and create then
		pendingContainer = {}
		pendingComputations[categoryName] = pendingContainer
	end

	return pendingContainer
end

function CacheMethods.Set(
	self: CacheManager,
	player: Player?,
	key: string,
	value: any,
	ttl: number?,
	category: string?
): ()
	local container: { [string]: CacheEntry } = getContainer(self, player, category)
	local expireAt: number = os.clock() + getTtl(ttl)
	container[key] = { value = value, expireAt = expireAt }

	local pendingContainer: { [string]: Promise.TypedPromise<any> }? =
		getPendingContainer(self, player, category, false)
	if pendingContainer then
		pendingContainer[key] = nil
	end
end

function CacheMethods.Get(self: CacheManager, player: Player?, key: string, category: string?): any?
	local container: { [string]: CacheEntry } = getContainer(self, player, category)
	local entry: CacheEntry? = container[key]
	if not entry then
		return
	end

	if isExpired(entry) then
		container[key] = nil

		return
	end

	return entry.value
end

function CacheMethods.GetOrCompute(
	self: CacheManager,
	player: Player?,
	key: string,
	compute: () -> any,
	ttl: number?,
	category: string?
): any?
	local container: { [string]: CacheEntry } = getContainer(self, player, category)
	local entry: CacheEntry? = container[key]
	if entry and not isExpired(entry) then
		return entry.value
	end

	local pendingContainer: { [string]: Promise.TypedPromise<any> } =
		getPendingContainer(self, player, category, true) :: { [string]: Promise.TypedPromise<any> }
	local pending: Promise.TypedPromise<any> = pendingContainer[key]
	if not pending then
		local newPending: Promise.TypedPromise<any>
		newPending = Promise.defer(function(resolve: (any) -> (), reject: () -> ()): ()
			local success: boolean, value: any = computeWithRetry(compute)
			if success then
				resolve(value)
			else
				reject()
			end
		end):andThen(function(value: any): any
			if pendingContainer[key] == newPending then
				pendingContainer[key] = nil
				container[key] = { value = value, expireAt = os.clock() + getTtl(ttl) }
			end

			return value
		end, function(): Promise.TypedPromise<any>
			if pendingContainer[key] == newPending then
				pendingContainer[key] = nil
			end

			return Promise.reject()
		end)
		pendingContainer[key] = newPending
		pending = newPending
	end

	local success: boolean, value: any = pending:await()
	if not success then
		return
	end

	return value
end

function CacheMethods.Has(self: CacheManager, player: Player?, key: string, category: string?): boolean
	local container: { [string]: CacheEntry } = getContainer(self, player, category)
	local entry: CacheEntry? = container[key]
	if not entry then
		return false
	end

	if isExpired(entry) then
		container[key] = nil

		return false
	end

	return true
end

function CacheMethods.Clear(self: CacheManager, player: Player?, key: string, category: string?): ()
	local categories: { [string]: { [string]: CacheEntry } } =
		getCategories(self, player, false) :: { [string]: { [string]: CacheEntry } }
	if not categories then
		return
	end

	local container: { [string]: CacheEntry } = categories[category or self.defaultCategory]
	if container then
		container[key] = nil
	end

	local pendingContainer: { [string]: Promise.TypedPromise<any> }? =
		getPendingContainer(self, player, category, false)
	if pendingContainer then
		pendingContainer[key] = nil
	end
end

function CacheMethods.ClearAll(self: CacheManager, player: Player?, category: string?): ()
	if not category then
		if player then
			local server: CacheManagerServer = self
			server.caches[player] = nil
			serverPendingComputations[player] = nil
		else
			local client: CacheManagerClient = self
			client.caches = {}
			table.clear(clientPendingComputations)
		end

		return
	end

	local categories: { [string]: { [string]: CacheEntry } } =
		getCategories(self, player, false) :: { [string]: { [string]: CacheEntry } }
	if categories then
		categories[category] = nil
	end

	local pendingComputations: PendingComputations = getPendingComputations(player, false) :: PendingComputations
	if pendingComputations then
		pendingComputations[category] = nil
	end
end

local CacheServer: CacheManagerServer = setmetatable({
	caches = {},
}, { __index = CacheMethods }) :: any

local CacheClient: CacheManagerClient = setmetatable({
	Clear = WithoutPlayer(CacheMethods.Clear),
	ClearAll = WithoutPlayer(CacheMethods.ClearAll),
	Get = WithoutPlayer(CacheMethods.Get),
	GetOrCompute = WithoutPlayer(CacheMethods.GetOrCompute),
	Has = WithoutPlayer(CacheMethods.Has),
	Set = WithoutPlayer(CacheMethods.Set),
	caches = {},
}, { __index = CacheMethods }) :: any

function CacheServer.PlayerRemoving(self: CacheManagerServer, player: Player): ()
	self.caches[player] = nil
	serverPendingComputations[player] = nil
end

return (RunService:IsServer() and CacheServer or CacheClient) :: CacheManager
