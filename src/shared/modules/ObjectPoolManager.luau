local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)

export type Pool = {
	free: { [number]: Instance },
	size: number,
	template: Instance?,
	create: (() -> Instance)?,
	reset: ((inst: Instance) -> ())?,
}

export type ObjectPoolManager = {
	path: InitializerTypes.ServerPath | InitializerTypes.ClientPath,
	defaultCategory: string,
	pools: { [string]: { [string]: Pool } },
	Register: (
		self: ObjectPoolManager,
		key: string,
		source: Instance | (() -> Instance),
		prewarmCount: number?,
		category: string?,
		reset: ((inst: Instance) -> ())?
	) -> (),
	Acquire: (self: ObjectPoolManager, key: string, category: string?, parent: Instance?) -> Instance?,
	Release: (self: ObjectPoolManager, key: string, instance: Instance, category: string?) -> (),
	Size: (self: ObjectPoolManager, key: string, category: string?) -> number,
	Clear: (self: ObjectPoolManager, key: string, category: string?) -> (),
	ClearAll: (self: ObjectPoolManager, category: string?) -> (),
}

local defaultCategory: string = "default"

local ObjectPoolManager: ObjectPoolManager = {
	type = "other",
	defaultCategory = defaultCategory,
	pools = {},
} :: any

local function getCategory(self: ObjectPoolManager, category: string?): { [string]: Pool }
	local categoryName: string = category or self.defaultCategory
	local categoryMap: { [string]: Pool } = self.pools[categoryName]
	if not categoryMap then
		categoryMap = {}
		self.pools[categoryName] = categoryMap
	end

	return categoryMap
end

local function ensurePool(self: ObjectPoolManager, key: string, category: string?): Pool
	local categoryMap = getCategory(self, category)
	local pool: Pool = categoryMap[key]
	if not pool then
		pool = {
			free = {},
			size = 0,
			template = nil,
			create = nil,
			reset = nil,
		}
		categoryMap[key] = pool
	end

	return pool
end

local function createFromPool(pool: Pool): Instance?
	if pool.template then
		return pool.template:Clone()
	end

	if pool.create then
		return pool.create()
	end

	return
end

local function prewarmPool(pool: Pool, count: number): ()
	local i: number = 1
	while i <= count do
		local instance: Instance? = createFromPool(pool)
		if instance then
			instance.Parent = nil
			pool.size += 1
			pool.free[pool.size] = instance
		end

		i += 1
	end
end

function ObjectPoolManager:Register(
	key: string,
	source: Instance | (() -> Instance),
	prewarmCount: number?,
	category: string?,
	reset: ((inst: Instance) -> ())?
): ()
	local pool: Pool = ensurePool(self, key, category)

	if typeof(source) == "Instance" then
		pool.template = source :: Instance
	else
		pool.create = source :: () -> Instance
	end

	pool.reset = reset

	if prewarmCount and prewarmCount > 0 then
		prewarmPool(pool, prewarmCount)
	end
end

function ObjectPoolManager:Acquire(key: string, category: string?, parent: Instance?): Instance?
	local pool: Pool = ensurePool(self, key, category)
	if pool.size == 0 then
		return
	end

	local inst: Instance = pool.free[pool.size] :: Instance
	pool.free[pool.size] = nil
	pool.size -= 1

	if parent then
		inst.Parent = parent
	end

	return inst
end

function ObjectPoolManager:Release(key: string, instance: Instance, category: string?): ()
	instance.Parent = nil

	local pool: Pool = ensurePool(self, key, category)
	if pool.reset then
		pool.reset(instance)
	end

	pool.size += 1
	pool.free[pool.size] = instance
end

function ObjectPoolManager:Size(key: string, category: string?): number
	local pool: Pool = ensurePool(self, key, category)

	return pool.size
end

function ObjectPoolManager:Clear(key: string, category: string?): ()
	local categoryName: string = category or self.defaultCategory
	local categoryMap = self.pools[categoryName]
	if not categoryMap then
		return
	end

	categoryMap[key] = nil
end

function ObjectPoolManager:ClearAll(category: string?): ()
	if not category then
		self.pools = {}

		return
	end

	self.pools[category] = nil
end

return ObjectPoolManager
