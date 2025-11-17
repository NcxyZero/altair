local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Logger)

local isServer: boolean = RunService:IsServer()

export type CacheEntry = {
	value: any,
	expireAt: number,
}

export type CacheManagerServer = {
	path: InitializerTypes.ServerPath,
	caches: { [Player]: { [string]: { [string]: CacheEntry } } },
	defaultCategory: string,
	Set: (self: CacheManager, player: Player, key: string, value: any, ttl: number?, category: string?) -> (),
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
	Clear: (self: CacheManager, player: Player, key: string, category: string?) -> (),
	ClearAll: (self: CacheManager, player: Player, category: string?) -> (),
	PlayerRemoving: (self: CacheManager, player: Player) -> (),
}

export type CacheManagerClient = {
	path: InitializerTypes.ClientPath,
	caches: { [string]: { [string]: CacheEntry } },
	defaultCategory: string,
	Set: (self: CacheManager, key: string, value: any, ttl: number?, category: string?) -> (),
	Get: (self: CacheManager, key: string, category: string?) -> any?,
	GetOrCompute: (self: CacheManager, key: string, compute: () -> any, ttl: number?, category: string?) -> any?,
	Has: (self: CacheManager, key: string, category: string?) -> boolean,
	Clear: (self: CacheManager, key: string, category: string?) -> (),
	ClearAll: (self: CacheManager, category: string?) -> (),
}

export type CacheManager = CacheManagerServer & CacheManagerClient

local defaultCategory: string = "default"

local function getTtl(ttl: number?): number
	local configured: number = GameConfig.core.cacheTimeout
	return ttl and ttl > 0 and ttl or configured
end

local CacheMeta = {
	type = "other",
	defaultCategory = defaultCategory,
}

local CacheServer: CacheManagerServer = table.clone(CacheMeta) :: any
local CacheClient: CacheManagerClient = table.clone(CacheMeta) :: any

CacheServer.caches = {}
CacheClient.caches = {}

local function getServerContainer(self: CacheManagerServer, player: Player, category: string?): { [string]: CacheEntry }
	local playerMap: { [string]: { [string]: CacheEntry } } = self.caches[player]
	if not playerMap then
		playerMap = {}
		self.caches[player] = playerMap
	end

	local categoryName: string = category or self.defaultCategory
	local categoryMap: { [string]: CacheEntry } = playerMap[categoryName]
	if not categoryMap then
		categoryMap = {}
		playerMap[categoryName] = categoryMap
	end

	return categoryMap
end

local function getClientContainer(self: CacheManagerClient, category: string?): { [string]: CacheEntry }
	local categoryName: string = category or self.defaultCategory
	local categoryMap: { [string]: CacheEntry } = self.caches[categoryName]
	if not categoryMap then
		categoryMap = {}
		self.caches[categoryName] = categoryMap
	end

	return categoryMap
end

local function isExpired(entry: CacheEntry): boolean
	return os.clock() >= entry.expireAt
end

local function computeWithRetry(compute: () -> any): (boolean, any)
	local retries: number = 0

	repeat
		local ok: boolean, value: any = xpcall(function(): any
			return compute()
		end, function(err: string): ()
			Logger.warn(err)
		end)

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

function CacheServer:Set(player: Player, key: string, value: any, ttl: number?, category: string?): ()
	local container: { [string]: CacheEntry } = getServerContainer(self, player, category)
	local expireAt: number = os.clock() + getTtl(ttl)
	container[key] = { value = value, expireAt = expireAt }
end

function CacheClient:Set(key: string, value: any, ttl: number?, category: string?): ()
	local container: { [string]: CacheEntry } = getClientContainer(self, category)
	local expireAt: number = os.clock() + getTtl(ttl)
	container[key] = { value = value, expireAt = expireAt }
end

function CacheServer:Get(player: Player, key: string, category: string?): any?
	local container: { [string]: CacheEntry } = getServerContainer(self, player, category)
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

function CacheClient:Get(key: string, category: string?): any?
	local container: { [string]: CacheEntry } = getClientContainer(self, category)
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

function CacheServer:GetOrCompute(
	player: Player,
	key: string,
	compute: () -> any,
	ttl: number?,
	category: string?
): any?
	local container: { [string]: CacheEntry } = getServerContainer(self, player, category)
	local entry: CacheEntry? = container[key]
	if entry and not isExpired(entry) then
		return entry.value
	end

	local ok: boolean, value: any = computeWithRetry(compute)
	if not ok then
		return
	end

	local expireAt: number = os.clock() + getTtl(ttl)
	container[key] = { value = value, expireAt = expireAt }

	return value
end

function CacheClient:GetOrCompute(key: string, compute: () -> any, ttl: number?, category: string?): any?
	local container: { [string]: CacheEntry } = getClientContainer(self, category)
	local entry: CacheEntry? = container[key]
	if entry and not isExpired(entry) then
		return entry.value
	end

	local ok: boolean, value: any = computeWithRetry(compute)
	if not ok then
		return
	end

	local expireAt: number = os.clock() + getTtl(ttl)
	container[key] = { value = value, expireAt = expireAt }

	return value
end

function CacheServer:Has(player: Player, key: string, category: string?): boolean
	local container: { [string]: CacheEntry } = getServerContainer(self, player, category)
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

function CacheClient:Has(key: string, category: string?): boolean
	local container: { [string]: CacheEntry } = getClientContainer(self, category)
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

function CacheServer:Clear(player: Player, key: string, category: string?): ()
	local container: { [string]: CacheEntry } = getServerContainer(self, player, category)
	container[key] = nil
end

function CacheClient:Clear(key: string, category: string?): ()
	local container: { [string]: CacheEntry } = getClientContainer(self, category)
	container[key] = nil
end

function CacheServer:ClearAll(player: Player, category: string?): ()
	if not category then
		self.caches[player] = nil

		return
	end

	local playerMap: { [string]: { [string]: CacheEntry } } = self.caches[player]
	if playerMap then
		playerMap[category] = nil
	end
end

function CacheClient:ClearAll(category: string?): ()
	if not category then
		self.caches = {}

		return
	end

	self.caches[category] = nil
end

function CacheServer:PlayerRemoving(player: Player): ()
	self.caches[player] = nil
end

return (isServer and CacheServer or CacheClient) :: CacheManager
