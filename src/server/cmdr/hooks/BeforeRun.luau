local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)

export type CacheEntry = {
	rank: number,
	timestamp: number,
}

local cacheRefreshTime: number = GameConfig.cmdr.cacheRefreshTime
local roleData: { groupId: number?, rank: number } = GameConfig.roles[GameConfig.cmdr.role]
local requiredGroup: number = roleData.groupId or game.CreatorType == Enum.CreatorType.Group and game.CreatorId or 0
local requiredRank: number = roleData.rank -- also in user-owned games, where non-members of the group have rank 0

-- command groups everyone may run; every other group, including Cmdr's DefaultUtil, needs the Cmdr role
local PUBLIC_GROUPS: { [string]: boolean } = {
	Help = true, -- Cmdr's help only lists the commands on the client
}

local cache: { [number]: CacheEntry } = {}

local function checkRank(player: Player): number
	local userId: number = player.UserId
	local currentTime: number = os.time()
	local cacheEntry: CacheEntry? = cache[userId]

	if cacheEntry and (currentTime - cacheEntry.timestamp < cacheRefreshTime) then
		return cacheEntry.rank
	end

	local success: boolean, rank: any = pcall(function(): number
		local membership: { IsMember: boolean, Roles: { { Rank: number } } } =
			GroupService:GetRolesInGroupAsync(userId, requiredGroup)
		if not membership.IsMember then
			return 0
		end

		local highestRank: number = 0
		for _index: number, role: { Rank: number } in membership.Roles do
			highestRank = math.max(highestRank, role.Rank)
		end

		return highestRank
	end)
	if not success then
		return 0
	end

	cache[userId] = {
		rank = rank,
		timestamp = currentTime,
	}

	return rank
end

local function adminPermissionCheck(player: Player): boolean
	if RunService:IsStudio() or table.find(GameConfig.cmdr.players, player.UserId) then
		return true
	end
	if requiredGroup == 0 then
		return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
	end

	return checkRank(player) >= requiredRank
end

return function(registry): ()
	registry:RegisterHook("BeforeRun", function(context): string?
		-- An allow-list, because Cmdr runs any command a client sends: DefaultUtil's var and var= read and write
		-- Cmdr's DataStore on the server, and DefaultDebug's fetch sends HTTP requests from it. The hook also runs on
		-- clients, so a client without the role is denied Cmdr's auto-run aliases and their `var init` server read.
		if PUBLIC_GROUPS[context.Group] or adminPermissionCheck(context.Executor) then
			return
		end

		return "You don't have permission to run this command"
	end)
end
