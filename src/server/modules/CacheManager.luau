local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Logger)
local MonetizationConfig = require(ReplicatedStorage.shared.config.MonetizationConfig)

export type CacheManager = {
	type: string,
	path: InitializerTypes.ServerPath,
	index: number,
	cacheTemplate: {
		monetization: {},
	},
	cache: { [Player]: {} },
	CheckCache: (self: CacheManager, player: Player, cacheType: string, conditionType: string, name: string) -> boolean,
	checkers: {
		monetization: (player: Player, conditionType: string, name: string) -> boolean,
	},
	CheckCondition: (
		self: CacheManager,
		player: Player,
		cacheType: string,
		conditionType: string,
		name: string
	) -> boolean,
	Init: (self: CacheManager, path: InitializerTypes.ServerPath) -> (),
}

local CacheManager: CacheManager = {} :: CacheManager
CacheManager.type = "controller"
CacheManager.index = 1

CacheManager.cacheTemplate = {
	monetization = {},
}
CacheManager.cache = {}

function CacheManager:CheckCache(player: Player, cacheType: string, conditionType: string, name: string): boolean
	local cacheEntry = self.cache
	local keys = { player, cacheType, conditionType, name }
	local keysAmount: number = #keys
	local timeNow: number = DateTime.now().UnixTimestamp

	for index: number, key: Player | string in keys do
		if not cacheEntry[key] then
			cacheEntry[key] = index == keysAmount and {
				timestamp = timeNow,
			} or {}
		end
		cacheEntry = cacheEntry[key]
	end

	if timeNow - cacheEntry.timestamp > GameConfig.core.cacheTimeout then
		cacheEntry.timestamp = timeNow

		return self.checkers[cacheType](player, conditionType, name)
	else
		return cacheEntry.value or self.checkers[cacheType](player, conditionType, name)
	end
end

CacheManager.checkers = {
	monetization = function(player: Player, conditionType: string, name: string): boolean
		local data = CacheManager.path.controller.ServerData
			:WaitForPlayerProfile(player)
			:expect().producer
			.getState().monetization[conditionType][name]
		if data == true then
			return data
		end

		local retries: number = 0
		local result: boolean, pass: boolean
		repeat
			pass = xpcall(function(): ()
				if conditionType == "passes" then
					result = MarketplaceService:UserOwnsGamePassAsync(
						player.UserId,
						MonetizationConfig[conditionType][name :: any]
					)
				end
			end, function(err: string): ()
				Logger.warn(err)
				retries += 1
				task.wait(GameConfig.core.cacheErrorTimeout)
			end)
		until pass or retries >= GameConfig.core.cacheErrorMaxRetries

		return result
	end,
}

function CacheManager:CheckCondition(player: Player, cacheType: string, conditionType: string, name: string): boolean
	return self:CheckCache(player, cacheType, conditionType, name)
end

function CacheManager:Init(): ()
	Players.PlayerRemoving:Connect(function(player: Player): ()
		self.cache[player] = nil
	end)

	--! FOR SOLO TEST !--
	-- task.delay(5, function(): ()
	-- 	print(self:CheckCondition(Players:GetPlayers()[1], "monetization", "passes", "test"))
	-- end)
end

return CacheManager
