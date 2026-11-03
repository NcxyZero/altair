export type GameConfig = {
	cmdr: {
		activationKeys: { Enum.KeyCode },
		cacheRefreshTime: number,
		players: { number },
		role: string,
	},
	core: {
		cacheErrorMaxRetries: number,
		cacheErrorTimeout: number,
		cacheTimeout: number,
		monetizationOfferCreationAllowed: boolean,
		playerCollisionsDisabled: boolean,
		raycastDetectionTimeout: number,
		resetButtonDisabled: boolean,
	},
	data: {
		datastoreKey: string,
		playerKeyPattern: string,
		playerProfileInvokeTimeout: number,
		playerProfileSyncInterval: number,
	},
	debug: {
		loggerShowInGame: boolean,
		loggerShowInStudio: boolean,
		onScreenOutputMaxLines: number,
		onScreenOutputMinRole: string,
		onScreenOutputShowInGame: boolean,
		onScreenOutputShowInStudio: boolean,
		onScreenOutputShowOnMobile: boolean,
	},
	game: {
		antiKick: {
			enabled: boolean,
			idleSeconds: number,
			requestCooldown: number,
			retrySeconds: number,
		},
		friendBoostApiBurstCapacity: number,
		friendBoostApiRequestsPerMinute: number,
		friendBoostClientRefreshCooldown: number,
		friendBoostEnabled: boolean,
		friendBoostPairCacheDuration: number,
		friendBoostPercentPerFriend: number,
		limitedItems: {
			[string]: {
				amount: number,
				itemKey: string,
				stockName: string,
			},
		},
		publicGame: {
			groupId: number,
			placeId: number,
			universeId: number,
		},
		vipChatTag: {
			attribute: string,
			enabled: boolean,
			prefix: string,
		},
	},
	roles: {
		[string]: {
			groupId: number?,
			rank: number,
		},
	},
	ui: {
		billboardVisibility: {
			defaultMultiplier: number,
			tagMultipliers: { [string]: number },
		},
		buttonSounds: {
			pressSoundId: string,
			pressVolume: number,
		}?,
		eventPrompt: {
			actionText: string,
			apiRefreshInterval: number,
			apiRetryInterval: number,
			maximumDistance: number,
			scheduleRefreshInterval: number,
			statusRefreshInterval: number,
		},
		magmaGradient: {
			color: ColorSequence,
			speed: number,
		},
		notifications: {
			defaultDuration: number,
			fadeInTime: number,
			fadeOutTime: number,
			maximumDuration: number,
			minimumDuration: number,
			soundId: number,
			soundPlaybackSpeed: number,
			soundVolume: number,
		},
		strokeAdjuster: {
			billboardUpdateInterval: number,
			defaultBillboardDistance: number,
			excludedGuiNames: { string },
			minimumBillboardDistance: number,
			referenceViewportSize: Vector2,
		},
		windowFieldOfView: {
			enabled: boolean,
			open: number,
		},
	},
}

local gameConfig: GameConfig = {
	cmdr = {
		activationKeys = {
			Enum.KeyCode.F2,
		},
		cacheRefreshTime = 30,
		players = {}, -- user IDs allowed to use Cmdr and DevLogger in live servers regardless of group rank
		role = "admin",
	},
	core = {
		cacheErrorMaxRetries = 5,
		cacheErrorTimeout = 1.5,
		cacheTimeout = 15,
		monetizationOfferCreationAllowed = false,
		playerCollisionsDisabled = true,
		raycastDetectionTimeout = 0.1,
		resetButtonDisabled = false, -- true disables the Reset Character button of the Roblox menu; false keeps Roblox's default
	},
	data = {
		datastoreKey = "DEV",
		playerKeyPattern = "%d",
		playerProfileInvokeTimeout = 30,
		playerProfileSyncInterval = 30,
	},
	debug = {
		loggerShowInGame = false,
		loggerShowInStudio = true,
		onScreenOutputMaxLines = 5,
		onScreenOutputMinRole = "admin",
		onScreenOutputShowInGame = false,
		onScreenOutputShowInStudio = true,
		onScreenOutputShowOnMobile = false,
	},
	game = {
		antiKick = {
			enabled = false, -- AntiKickController does nothing on the client and the server unless true
			idleSeconds = 60 * 19, -- rejoins idle players before the 20-minute Roblox idle kick
			requestCooldown = 5,
			retrySeconds = 10,
		},
		friendBoostApiBurstCapacity = 5,
		friendBoostApiRequestsPerMinute = 60,
		friendBoostClientRefreshCooldown = 10,
		friendBoostEnabled = false, -- FriendBoostController does nothing on the client and the server unless true
		friendBoostPairCacheDuration = 30,
		friendBoostPercentPerFriend = 10,
		-- keyed by MonetizationConfig product name, for example:
		-- Test1 = { amount = 500, itemKey = "Test1", stockName = "Test1Limited_v1" },
		limitedItems = {},
		publicGame = {
			groupId = 0,
			placeId = 0,
			universeId = 0,
		},
		vipChatTag = {
			attribute = "IsVIP", -- player attribute that marks a VIP when true; ServerMonetization sets IsVIP for owners of the VIP game pass
			enabled = false, -- VIPChatTagController does nothing unless true
			prefix = '<font color="#FFD83D">[VIP]</font>', -- rich text put before a VIP's name in chat
		},
	},
	roles = {
		admin = {
			rank = 200,
		},
	},
	ui = {
		billboardVisibility = {
			defaultMultiplier = 1,
			tagMultipliers = {}, -- CollectionService tag of a billboard ancestor -> MaxDistance multiplier
		},
		-- buttonSounds = { pressSoundId = "rbxassetid://421058925", pressVolume = 0.4 },
		eventPrompt = {
			actionText = "Follow Event",
			apiRefreshInterval = 60,
			apiRetryInterval = 15,
			maximumDistance = 10,
			scheduleRefreshInterval = 1,
			statusRefreshInterval = 30,
		},
		magmaGradient = {
			color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 53, 3)),
				ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 87, 10)),
				ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 116, 16)),
				ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 132, 75)),
				ColorSequenceKeypoint.new(0.8, Color3.fromRGB(255, 54, 14)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 53, 3)),
			}),
			speed = 0.3,
		},
		notifications = {
			defaultDuration = 4,
			fadeInTime = 0.06,
			fadeOutTime = 0.65,
			maximumDuration = 30,
			minimumDuration = 0.5,
			soundId = 0, -- 0 disables the notification sound
			soundPlaybackSpeed = 1,
			soundVolume = 0.5,
		},
		strokeAdjuster = {
			billboardUpdateInterval = 1,
			defaultBillboardDistance = 10,
			excludedGuiNames = {}, -- ScreenGui names whose strokes are not rescaled, for example { "BackpackGui" }
			minimumBillboardDistance = 0.1,
			referenceViewportSize = Vector2.new(1920, 1080),
		},
		windowFieldOfView = {
			enabled = false, -- true tweens the camera to open while an OpenGui window is open, then back to the field of view from before the first window opened; false never touches the camera
			open = 40, -- camera field of view, in degrees, while a window is open
		},
	},
}

return gameConfig
