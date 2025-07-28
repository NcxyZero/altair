local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)

export type CacheEntry = {
	rank: number,
	timestamp: number,
}

local cacheRefreshTime: number = GameConfig.cmdr.cacheRefreshTime
local roleData: { groupId: number?, rank: number } = GameConfig.roles[GameConfig.cmdr.role]
local requiredGroup: number = roleData.groupId or game.CreatorType == Enum.CreatorType.Group and game.CreatorId or 0
local requiredRank: number = game.CreatorType == Enum.CreatorType.User and 0 or roleData.rank

local cache = {}

local function checkRank(player: Player): number
	local userId: number = player.UserId
	local currentTime: number = os.time()
	local cacheEntry = cache[userId]

	if cacheEntry and (currentTime - cacheEntry.timestamp < cacheRefreshTime) then
		return cacheEntry.rank
	end

	local rank: number = player:GetRankInGroup(requiredGroup)

	cache[userId] = {
		rank = rank,
		timestamp = currentTime,
	}

	return rank
end

local function adminPermissionCheck(player: Player): boolean
	return checkRank(player) >= requiredRank
end

return function(registry): ()
	registry:RegisterHook("BeforeRun", function(context): string?
		if
			(context.Group == "Admin" or context.Group == "DefaultAdmin") and not adminPermissionCheck(context.Executor)
		then
			return "You don't have permission to run this command"
		end

		return
	end)
end
