local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)

local isServer: boolean = RunService:IsServer()

export type CooldownManagerServer = {
	path: InitializerTypes.ServerPath,
	defaultCategory: string,
	cooldowns: { [Player]: { [string]: { [string]: number } } },
	Set: (self: CooldownManager, player: Player, key: string, duration: number, category: string?) -> (),
	IsReady: (self: CooldownManager, player: Player, key: string, category: string?) -> boolean,
	GetRemaining: (self: CooldownManager, player: Player, key: string, category: string?) -> number,
	Clear: (self: CooldownManager, player: Player, key: string, category: string?) -> (),
	ClearAll: (self: CooldownManager, player: Player, category: string?) -> (),
	PlayerRemoving: (self: CooldownManager, player: Player) -> (),
}

export type CooldownManagerClient = {
	path: InitializerTypes.ClientPath,
	defaultCategory: string,
	cooldowns: { [string]: { [string]: number } },
	Set: (self: CooldownManager, key: string, duration: number, category: string?) -> (),
	IsReady: (self: CooldownManager, key: string, category: string?) -> boolean,
	GetRemaining: (self: CooldownManager, key: string, category: string?) -> number,
	Clear: (self: CooldownManager, key: string, category: string?) -> (),
	ClearAll: (self: CooldownManager, category: string?) -> (),
}

export type CooldownManager = CooldownManagerServer & CooldownManagerClient

local defaultCategory: string = "default"

local CooldownMeta = {
	type = "other",
	defaultCategory = defaultCategory,
}

local CooldownServer: CooldownManagerServer = table.clone(CooldownMeta) :: any
local CooldownClient: CooldownManagerClient = table.clone(CooldownMeta) :: any

CooldownServer.cooldowns = {}
CooldownClient.cooldowns = {}

local function getServerCategoryContainer(
	self: CooldownManagerServer,
	player: Player,
	category: string?
): { [string]: number }
	local playerMap: { [string]: { [string]: number } } = self.cooldowns[player]
	if not playerMap then
		playerMap = {}
		self.cooldowns[player] = playerMap
	end

	local categoryName: string = category or self.defaultCategory
	local categoryMap: { [string]: number } = playerMap[categoryName]
	if not categoryMap then
		categoryMap = {}
		playerMap[categoryName] = categoryMap
	end

	return categoryMap
end

local function getClientCategoryContainer(self: CooldownManagerClient, category: string?): { [string]: number }
	local categoryName: string = category or self.defaultCategory
	local categoryMap: { [string]: number } = self.cooldowns[categoryName]
	if not categoryMap then
		categoryMap = {}
		self.cooldowns[categoryName] = categoryMap
	end

	return categoryMap
end

function CooldownServer:Set(player: Player, key: string, duration: number, category: string?): ()
	local container: { [string]: number } = getServerCategoryContainer(self, player, category)
	container[key] = os.clock() + duration
end

function CooldownClient:Set(key: string, duration: number, category: string?): ()
	local container: { [string]: number } = getClientCategoryContainer(self, category)
	container[key] = os.clock() + duration
end

function CooldownServer:IsReady(player: Player, key: string, category: string?): boolean
	local container: { [string]: number } = getServerCategoryContainer(self, player, category)
	local expire: number? = container and container[key]
	if not expire then
		return true
	end

	return os.clock() >= expire
end

function CooldownClient:IsReady(key: string, category: string?): boolean
	local container: { [string]: number } = getClientCategoryContainer(self, category)
	local expire: number? = container and container[key]
	if not expire then
		return true
	end

	return os.clock() >= expire
end

function CooldownServer:GetRemaining(player: Player, key: string, category: string?): number
	local container: { [string]: number } = getServerCategoryContainer(self, player, category)
	local expire: number? = container[key]
	if not expire then
		return 0
	end

	local remaining: number = expire - os.clock()
	if remaining <= 0 then
		return 0
	end

	return remaining
end

function CooldownClient:GetRemaining(key: string, category: string?): number
	local container: { [string]: number } = getClientCategoryContainer(self, category)
	local expire: number? = container[key]
	if not expire then
		return 0
	end

	local remaining: number = expire - os.clock()
	if remaining <= 0 then
		return 0
	end

	return remaining
end

function CooldownServer:Clear(player: Player, key: string, category: string?): ()
	local container: { [string]: number } = getServerCategoryContainer(self, player, category)
	container[key] = nil
end

function CooldownClient:Clear(key: string, category: string?): ()
	local container: { [string]: number } = getClientCategoryContainer(self, category)
	container[key] = nil
end

function CooldownServer:ClearAll(player: Player, category: string?): ()
	if not category then
		self.cooldowns[player] = nil

		return
	end

	local playerMap: { [string]: { [string]: number } } = self.cooldowns[player]
	if playerMap then
		playerMap[category] = nil
	end
end

function CooldownClient:ClearAll(category: string?): ()
	if not category then
		self.cooldowns = {}

		return
	end

	self.cooldowns[category] = nil
end

function CooldownServer:PlayerRemoving(player: Player): ()
	self.cooldowns[player] = nil
end

return (isServer and CooldownServer or CooldownClient) :: CooldownManager
