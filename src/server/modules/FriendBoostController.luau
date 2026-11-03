local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CooldownManager = require(ReplicatedStorage.shared.modules.CooldownManager)
local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local GetBridge = require(ReplicatedStorage.util.Core.GetBridge)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Core.Logger)
local Maid = require(ReplicatedStorage.package.Maid)

export type PlayerFriendState = {
	friendUserIds: { [number]: boolean },
}

export type PairCacheEntry = {
	areFriends: boolean,
	expiresAt: number,
	firstUserId: number,
	secondUserId: number,
}

export type PendingPairRequest = {
	forceRefresh: boolean,
	otherPlayer: Player,
	player: Player,
}

export type FriendBoostController = {
	ConsumeApiBudget: (self: FriendBoostController) -> boolean,
	GetBoostMultiplier: (self: FriendBoostController, player: Player) -> number,
	GetCachedFriendship: (self: FriendBoostController, firstUserId: number, secondUserId: number) -> boolean?,
	Init: (self: FriendBoostController) -> (),
	Physics: (self: FriendBoostController, delta: number) -> (),
	PlayerAdded: (self: FriendBoostController, player: Player) -> (),
	PlayerRemoving: (self: FriendBoostController, player: Player) -> (),
	QueuePairRefresh: (
		self: FriendBoostController,
		player: Player,
		otherPlayer: Player,
		forceRefresh: boolean?
	) -> (),
	RefreshPairAsync: (
		self: FriendBoostController,
		player: Player,
		otherPlayer: Player,
		forceRefresh: boolean?
	) -> (),
	SetCachedFriendship: (
		self: FriendBoostController,
		firstUserId: number,
		secondUserId: number,
		areFriends: boolean
	) -> (),
	SetFriendship: (self: FriendBoostController, player: Player, otherPlayer: Player, areFriends: boolean) -> (),
	UpdatePlayerAttributes: (self: FriendBoostController, player: Player) -> (),
	pairCache: { [string]: PairCacheEntry },
	pairRequestsInFlight: { [string]: boolean },
	pendingPairRequests: { [string]: PendingPairRequest },
	playerStates: { [Player]: PlayerFriendState },
	apiTokens: number,
	index: number,
	lastApiTokenRefill: number,
	nextQueueAttemptTick: number,
	type: string,
	path: InitializerTypes.ServerPath,
	maid: Maid.Maid,
}

local FriendBoostController: FriendBoostController = {} :: any
FriendBoostController.apiTokens = 0
FriendBoostController.index = 2
FriendBoostController.lastApiTokenRefill = os.clock()
FriendBoostController.maid = Maid.new()
FriendBoostController.pairCache = {}
FriendBoostController.pairRequestsInFlight = {}
FriendBoostController.pendingPairRequests = {}
FriendBoostController.playerStates = {}
FriendBoostController.nextQueueAttemptTick = 0
FriendBoostController.type = "controller"

local FRIEND_BOOST_ATTRIBUTE: string = "FriendBoostPercent"
local FRIEND_BOOST_COOLDOWN_CATEGORY: string = "FriendBoost"
local FRIEND_BOOST_REFRESH_COOLDOWN_KEY: string = "ClientRefresh"
local FRIEND_COUNT_ATTRIBUTE: string = "FriendsInServer"
local FRIEND_BOOST_BRIDGE: any = GetBridge("FriendBoost")

local function getPairCacheKey(firstUserId: number, secondUserId: number): string
	local lowerUserId: number = math.min(firstUserId, secondUserId)
	local upperUserId: number = math.max(firstUserId, secondUserId)

	return `{lowerUserId}:{upperUserId}`
end

function FriendBoostController:ConsumeApiBudget(): boolean
	local requestsPerMinute: number = math.max(GameConfig.game.friendBoostApiRequestsPerMinute, 1)
	local burstCapacity: number = math.clamp(GameConfig.game.friendBoostApiBurstCapacity, 1, requestsPerMinute)
	local currentTime: number = os.clock()
	local elapsedTime: number = math.max(currentTime - self.lastApiTokenRefill, 0)
	local tokensPerSecond: number = requestsPerMinute / 60

	self.apiTokens = math.min(self.apiTokens + (elapsedTime * tokensPerSecond), burstCapacity)
	self.lastApiTokenRefill = currentTime

	if self.apiTokens < 1 then
		return false
	end

	self.apiTokens -= 1

	return true
end

function FriendBoostController:GetCachedFriendship(firstUserId: number, secondUserId: number): boolean?
	local cacheKey: string = getPairCacheKey(firstUserId, secondUserId)
	local entry: PairCacheEntry? = self.pairCache[cacheKey]
	if not entry then
		return
	end

	if entry.expiresAt <= os.clock() then
		self.pairCache[cacheKey] = nil

		return
	end

	return entry.areFriends
end

function FriendBoostController:GetBoostMultiplier(player: Player): number
	local rawBoostPercent: unknown = player:GetAttribute(FRIEND_BOOST_ATTRIBUTE)
	local boostPercent: number = type(rawBoostPercent) == "number" and math.max(rawBoostPercent, 0) or 0

	return 1 + (boostPercent / 100)
end

function FriendBoostController:Init(): ()
	self.maid:DoCleaning()
	self.maid = Maid.new()

	local requestsPerMinute: number = math.max(GameConfig.game.friendBoostApiRequestsPerMinute, 1)
	self.apiTokens = math.clamp(GameConfig.game.friendBoostApiBurstCapacity, 1, requestsPerMinute)
	self.lastApiTokenRefill = os.clock()
	self.pairCache = {}
	self.pairRequestsInFlight = {}
	self.pendingPairRequests = {}
	self.nextQueueAttemptTick = 0

	if not GameConfig.game.friendBoostEnabled then
		return
	end

	self.maid:GiveTask(FRIEND_BOOST_BRIDGE:Connect(function(player: Player, payload: unknown): ()
		if not self.playerStates[player] or type(payload) ~= "table" then
			return
		end

		-- Whole numbers only, so NaN or infinity never reaches GetPlayerByUserId.
		local rawUserId: unknown = (payload :: any).userId
		local otherPlayer: Player? = type(rawUserId) == "number"
				and rawUserId % 1 == 0
				and Players:GetPlayerByUserId(rawUserId)
			or nil
		if not otherPlayer or otherPlayer == player or not self.playerStates[otherPlayer] then
			return
		end

		-- A request inside the cooldown waits in the queue, so friending several players in a row rechecks every pair.
		if not CooldownManager:IsReady(player, FRIEND_BOOST_REFRESH_COOLDOWN_KEY, FRIEND_BOOST_COOLDOWN_CATEGORY) then
			self:QueuePairRefresh(player, otherPlayer, true)

			return
		end

		CooldownManager:Set(
			player,
			FRIEND_BOOST_REFRESH_COOLDOWN_KEY,
			math.max(GameConfig.game.friendBoostClientRefreshCooldown, 0),
			FRIEND_BOOST_COOLDOWN_CATEGORY
		)

		task.spawn(self.RefreshPairAsync, self, player, otherPlayer, true)
	end))
end

function FriendBoostController:PlayerAdded(player: Player): ()
	if not GameConfig.game.friendBoostEnabled then
		return
	end

	local state: PlayerFriendState = {
		friendUserIds = {},
	}
	self.playerStates[player] = state

	self:UpdatePlayerAttributes(player)

	for _index: number, otherPlayer: Player in Players:GetPlayers() do
		if otherPlayer == player then
			continue
		end

		task.spawn(self.RefreshPairAsync, self, player, otherPlayer)
	end
end

function FriendBoostController:PlayerRemoving(player: Player): ()
	self.playerStates[player] = nil

	CooldownManager:ClearAll(player, FRIEND_BOOST_COOLDOWN_CATEGORY)

	for cacheKey: string, entry: PairCacheEntry in self.pairCache do
		if entry.firstUserId == player.UserId or entry.secondUserId == player.UserId then
			self.pairCache[cacheKey] = nil
		end
	end

	for cacheKey: string, request: PendingPairRequest in self.pendingPairRequests do
		if request.player == player or request.otherPlayer == player then
			self.pendingPairRequests[cacheKey] = nil
		end
	end

	for otherPlayer: Player, otherState: PlayerFriendState in self.playerStates do
		if not otherState.friendUserIds[player.UserId] then
			continue
		end

		otherState.friendUserIds[player.UserId] = nil

		self:UpdatePlayerAttributes(otherPlayer)
	end
end

function FriendBoostController:Physics(_delta: number): ()
	if os.clock() < self.nextQueueAttemptTick then
		return
	end

	local cacheKey: any, request: any = next(self.pendingPairRequests)
	if not cacheKey or not request then
		return
	end

	self.pendingPairRequests[cacheKey] = nil

	local requestsPerMinute: number = math.max(GameConfig.game.friendBoostApiRequestsPerMinute, 1)
	self.nextQueueAttemptTick = os.clock() + (60 / requestsPerMinute)

	task.spawn(self.RefreshPairAsync, self, request.player, request.otherPlayer, request.forceRefresh)
end

function FriendBoostController:QueuePairRefresh(player: Player, otherPlayer: Player, forceRefresh: boolean?): ()
	local cacheKey: string = getPairCacheKey(player.UserId, otherPlayer.UserId)
	local existingRequest: PendingPairRequest? = self.pendingPairRequests[cacheKey]

	self.pendingPairRequests[cacheKey] = {
		forceRefresh = forceRefresh == true or (existingRequest ~= nil and existingRequest.forceRefresh == true),
		otherPlayer = otherPlayer,
		player = player,
	}

	local requestsPerMinute: number = math.max(GameConfig.game.friendBoostApiRequestsPerMinute, 1)
	local currentTime: number = os.clock()
	if self.nextQueueAttemptTick <= currentTime then
		self.nextQueueAttemptTick = currentTime + (60 / requestsPerMinute)
	end
end

function FriendBoostController:RefreshPairAsync(player: Player, otherPlayer: Player, forceRefresh: boolean?): ()
	if
		player.Parent ~= Players
		or otherPlayer.Parent ~= Players
		or not self.playerStates[player]
		or not self.playerStates[otherPlayer]
	then
		return
	end

	local cacheKey: string = getPairCacheKey(player.UserId, otherPlayer.UserId)

	if not forceRefresh then
		local cachedFriendship: boolean? = self:GetCachedFriendship(player.UserId, otherPlayer.UserId)
		if cachedFriendship ~= nil then
			self.pendingPairRequests[cacheKey] = nil
			self:SetFriendship(player, otherPlayer, cachedFriendship)

			return
		end
	end

	if self.pairRequestsInFlight[cacheKey] then
		self.pendingPairRequests[cacheKey] = nil

		return
	end

	if not self:ConsumeApiBudget() then
		self:QueuePairRefresh(player, otherPlayer, forceRefresh)

		return
	end

	self.pendingPairRequests[cacheKey] = nil
	self.pairRequestsInFlight[cacheKey] = true

	local success: boolean, areFriendsOrError: any = pcall(player.IsFriendsWithAsync, player, otherPlayer.UserId)
	self.pairRequestsInFlight[cacheKey] = nil

	if not success then
		Logger.warn(`Failed to check friendship between {player.Name} and {otherPlayer.Name}: {areFriendsOrError}`)

		return
	end

	if player.Parent ~= Players or otherPlayer.Parent ~= Players then
		return
	end

	local areFriends: boolean = areFriendsOrError == true

	self:SetCachedFriendship(player.UserId, otherPlayer.UserId, areFriends)
	self:SetFriendship(player, otherPlayer, areFriends)
end

function FriendBoostController:SetCachedFriendship(firstUserId: number, secondUserId: number, areFriends: boolean): ()
	local cacheKey: string = getPairCacheKey(firstUserId, secondUserId)
	local cacheDuration: number = math.max(GameConfig.game.friendBoostPairCacheDuration, 0)

	self.pairCache[cacheKey] = {
		areFriends = areFriends,
		expiresAt = os.clock() + cacheDuration,
		firstUserId = firstUserId,
		secondUserId = secondUserId,
	}
end

function FriendBoostController:SetFriendship(player: Player, otherPlayer: Player, areFriends: boolean): ()
	if player == otherPlayer then
		return
	end

	local playerState: PlayerFriendState? = self.playerStates[player]
	local otherPlayerState: PlayerFriendState? = self.playerStates[otherPlayer]
	if not playerState or not otherPlayerState then
		return
	end

	local normalizedFriendship: boolean = areFriends == true
	if
		(playerState.friendUserIds[otherPlayer.UserId] == true) == normalizedFriendship
		and (otherPlayerState.friendUserIds[player.UserId] == true) == normalizedFriendship
	then
		return
	end

	if normalizedFriendship then
		playerState.friendUserIds[otherPlayer.UserId] = true
		otherPlayerState.friendUserIds[player.UserId] = true
	else
		playerState.friendUserIds[otherPlayer.UserId] = nil
		otherPlayerState.friendUserIds[player.UserId] = nil
	end

	self:UpdatePlayerAttributes(player)
	self:UpdatePlayerAttributes(otherPlayer)
end

function FriendBoostController:UpdatePlayerAttributes(player: Player): ()
	local state: PlayerFriendState? = self.playerStates[player]
	if not state then
		return
	end

	local friendCount: number = 0
	for _userId: number, isFriend: boolean in state.friendUserIds do
		if isFriend then
			friendCount += 1
		end
	end

	local boostPercent: number = friendCount * GameConfig.game.friendBoostPercentPerFriend
	if player:GetAttribute(FRIEND_COUNT_ATTRIBUTE) ~= friendCount then
		player:SetAttribute(FRIEND_COUNT_ATTRIBUTE, friendCount)
	end

	if player:GetAttribute(FRIEND_BOOST_ATTRIBUTE) ~= boostPercent then
		player:SetAttribute(FRIEND_BOOST_ATTRIBUTE, boostPercent)
	end
end

return FriendBoostController
