local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)

export type IncomingMessageCallback = (message: TextChatMessage) -> TextChatMessageProperties?

export type VIPChatTagController = {
	HandleMessage: (self: VIPChatTagController, message: TextChatMessage) -> TextChatMessageProperties?,
	Init: (self: VIPChatTagController) -> (),
	OnIncomingMessage: IncomingMessageCallback,
	SetChainedCallback: (self: VIPChatTagController, callback: IncomingMessageCallback?) -> (),
	chainedCallback: IncomingMessageCallback?,
	index: number,
	type: string,
}

local VIPChatTagController: VIPChatTagController = {} :: any
VIPChatTagController.index = 1
VIPChatTagController.type = "controller"

-- GameConfig.game.vipChatTag tunables
local CONFIG: typeof(GameConfig.game.vipChatTag) = GameConfig.game.vipChatTag

-- Runs the chained callback first, then puts the tag before the prefix it chose (or the message's own prefix).
function VIPChatTagController:HandleMessage(message: TextChatMessage): TextChatMessageProperties?
	local chainedCallback: IncomingMessageCallback? = self.chainedCallback
	local properties: TextChatMessageProperties? = chainedCallback and chainedCallback(message) or nil
	local textSource: TextSource? = message.TextSource
	local player: Player? = textSource and Players:GetPlayerByUserId(textSource.UserId)
	if not player or player:GetAttribute(CONFIG.attribute) ~= true then
		return properties
	end

	local chainedPrefixText: string = properties and properties.PrefixText or ""
	local taggedProperties: TextChatMessageProperties = properties or Instance.new("TextChatMessageProperties")
	taggedProperties.PrefixText =
		`{CONFIG.prefix} {chainedPrefixText ~= "" and chainedPrefixText or message.PrefixText}`

	return taggedProperties
end

function VIPChatTagController.OnIncomingMessage(message: TextChatMessage): TextChatMessageProperties?
	return VIPChatTagController:HandleMessage(message)
end

-- TextChatService.OnIncomingMessage holds a single callback, and this controller owns it while the tag is enabled.
-- Game code hands its own callback over here instead of assigning it; with the tag disabled it is assigned directly.
function VIPChatTagController:SetChainedCallback(callback: IncomingMessageCallback?): ()
	self.chainedCallback = callback

	if not CONFIG.enabled then
		TextChatService.OnIncomingMessage = callback :: any
	end
end

function VIPChatTagController:Init(): ()
	if not CONFIG.enabled then
		return
	end

	-- A callback assigned earlier is chained when the engine lets scripts read it; Roblox can refuse to read callbacks,
	-- so SetChainedCallback is the reliable way to keep one.
	local success: boolean, previousCallback: unknown = pcall(function(): unknown
		return TextChatService.OnIncomingMessage
	end)
	if
		not self.chainedCallback
		and success
		and type(previousCallback) == "function"
		and previousCallback ~= VIPChatTagController.OnIncomingMessage
	then
		self.chainedCallback = previousCallback :: IncomingMessageCallback
	end

	TextChatService.OnIncomingMessage = VIPChatTagController.OnIncomingMessage
end

return VIPChatTagController
