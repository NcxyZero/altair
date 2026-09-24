local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local WithoutPlayer = require(ReplicatedStorage.util.WithoutPlayer)

export type CooldownManagerServer = {
	Clear: (self: CooldownManager, player: Player, key: string, category: string?) -> (),
	ClearAll: (self: CooldownManager, player: Player, category: string?) -> (),
	GetRemaining: (self: CooldownManager, player: Player, key: string, category: string?) -> number,
	IsReady: (self: CooldownManager, player: Player, key: string, category: string?) -> boolean,
	PlayerRemoving: (self: CooldownManager, player: Player) -> (),
	Set: (self: CooldownManager, player: Player, key: string, duration: number, category: string?) -> (),
	cooldowns: { [Player]: { [string]: { [string]: number } } },
	path: InitializerTypes.ServerPath,
	defaultCategory: string,
}

export type CooldownManagerClient = {
	Clear: (self: CooldownManager, key: string, category: string?) -> (),
	ClearAll: (self: CooldownManager, category: string?) -> (),
	GetRemaining: (self: CooldownManager, key: string, category: string?) -> number,
	IsReady: (self: CooldownManager, key: string, category: string?) -> boolean,
	Set: (self: CooldownManager, key: string, duration: number, category: string?) -> (),
	cooldowns: { [string]: { [string]: number } },
	path: InitializerTypes.ClientPath,
	defaultCategory: string,
}

export type CooldownManager = CooldownManagerServer & CooldownManagerClient

type CooldownMethods = {
	Clear: (self: CooldownManager, player: Player?, key: string, category: string?) -> (),
	ClearAll: (self: CooldownManager, player: Player?, category: string?) -> (),
	GetRemaining: (self: CooldownManager, player: Player?, key: string, category: string?) -> number,
	IsReady: (self: CooldownManager, player: Player?, key: string, category: string?) -> boolean,
	Set: (self: CooldownManager, player: Player?, key: string, duration: number, category: string?) -> (),
	defaultCategory: string,
	type: string,
}

local CooldownMethods: CooldownMethods = {
	type = "other",
	defaultCategory = "default",
} :: CooldownMethods

local function getCategories(
	self: CooldownManager,
	player: Player?,
	create: boolean
): { [string]: { [string]: number } }?
	if not player then
		local client: CooldownManagerClient = self

		return client.cooldowns
	end

	local server: CooldownManagerServer = self
	local categories: { [string]: { [string]: number } } = server.cooldowns[player]
	if not categories and create then
		categories = {}
		server.cooldowns[player] = categories
	end

	return categories
end

local function getContainer(self: CooldownManager, player: Player?, category: string?): { [string]: number }
	local categories: { [string]: { [string]: number } } =
		getCategories(self, player, true) :: { [string]: { [string]: number } }
	local categoryName: string = category or self.defaultCategory
	local container: { [string]: number } = categories[categoryName]
	if not container then
		container = {}
		categories[categoryName] = container
	end

	return container
end

function CooldownMethods.Set(
	self: CooldownManager,
	player: Player?,
	key: string,
	duration: number,
	category: string?
): ()
	local container: { [string]: number } = getContainer(self, player, category)
	container[key] = os.clock() + duration
end

function CooldownMethods.IsReady(self: CooldownManager, player: Player?, key: string, category: string?): boolean
	local container: { [string]: number } = getContainer(self, player, category)
	local expire: number? = container and container[key]
	if not expire then
		return true
	end

	return os.clock() >= expire
end

function CooldownMethods.GetRemaining(self: CooldownManager, player: Player?, key: string, category: string?): number
	local container: { [string]: number } = getContainer(self, player, category)
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

function CooldownMethods.Clear(self: CooldownManager, player: Player?, key: string, category: string?): ()
	local categories: { [string]: { [string]: number } } =
		getCategories(self, player, false) :: { [string]: { [string]: number } }
	if not categories then
		return
	end

	local container: { [string]: number } = categories[category or self.defaultCategory]
	if container then
		container[key] = nil
	end
end

function CooldownMethods.ClearAll(self: CooldownManager, player: Player?, category: string?): ()
	if not category then
		if player then
			local server: CooldownManagerServer = self
			server.cooldowns[player] = nil
		else
			local client: CooldownManagerClient = self
			client.cooldowns = {}
		end

		return
	end

	local categories: { [string]: { [string]: number } } =
		getCategories(self, player, false) :: { [string]: { [string]: number } }
	if categories then
		categories[category] = nil
	end
end

local CooldownServer: CooldownManagerServer = setmetatable({
	cooldowns = {},
}, { __index = CooldownMethods }) :: any

local CooldownClient: CooldownManagerClient = setmetatable({
	Clear = WithoutPlayer(CooldownMethods.Clear),
	ClearAll = WithoutPlayer(CooldownMethods.ClearAll),
	GetRemaining = WithoutPlayer(CooldownMethods.GetRemaining),
	IsReady = WithoutPlayer(CooldownMethods.IsReady),
	Set = WithoutPlayer(CooldownMethods.Set),
	cooldowns = {},
}, { __index = CooldownMethods }) :: any

function CooldownServer.PlayerRemoving(self: CooldownManagerServer, player: Player): ()
	self.cooldowns[player] = nil
end

return (RunService:IsServer() and CooldownServer or CooldownClient) :: CooldownManager
