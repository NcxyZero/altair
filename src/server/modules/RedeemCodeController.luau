local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConvertCurrency = require(ReplicatedStorage.util.Core.ConvertCurrency)
local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local GetBridge = require(ReplicatedStorage.util.Core.GetBridge)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Core.Logger)
local Maid = require(ReplicatedStorage.package.Maid)
local RedeemCodeConfig = require(ReplicatedStorage.shared.config.RedeemCodeConfig)

export type RedeemCodeController = {
	Init: (self: RedeemCodeController) -> (),
	PlayerRemoving: (self: RedeemCodeController, player: Player) -> (),
	Redeem: (self: RedeemCodeController, player: Player, codeInput: unknown) -> (),
	SendFeedback: (self: RedeemCodeController, player: Player, message: string, success: boolean) -> (),
	lastRequestAt: { [Player]: number },
	type: string,
	path: InitializerTypes.ServerPath,
	maid: Maid.Maid,
}

local RedeemCodeController: RedeemCodeController = {} :: any
RedeemCodeController.type = "controller"
RedeemCodeController.lastRequestAt = {}
RedeemCodeController.maid = Maid.new()

local MAX_CODE_LENGTH: number = 32 -- longest accepted code after trimming
local MAX_INPUT_LENGTH: number = MAX_CODE_LENGTH * 2 -- longest raw input trimmed; the trim pattern is quadratic, so longer input is rejected first
local REQUEST_COOLDOWN: number = 0.75 -- minimum seconds between two redeem requests of one player

local NOTIFICATION_BRIDGE: any = GetBridge("Notification") -- sends redeem feedback to the player
local REDEEM_CODE_BRIDGE: any = GetBridge("RedeemCode") -- receives codes entered in the ShopUI Codes block

local function normalizeCode(code: string): string
	return (code:upper():gsub("^%s*(.-)%s*$", "%1"))
end

function RedeemCodeController:SendFeedback(player: Player, message: string, success: boolean): ()
	NOTIFICATION_BRIDGE:Fire(player, {
		color = if success then RedeemCodeConfig.successColor else RedeemCodeConfig.errorColor,
		kind = if success then "notification" else "error", -- failures use the optional ErrorTemplate
		seconds = 3,
		text = message,
	})
end

function RedeemCodeController:Redeem(player: Player, codeInput: unknown): ()
	if player.Parent ~= Players then
		return
	end

	local now: number = os.clock()
	local lastRequest: number? = self.lastRequestAt[player]
	if lastRequest and now - lastRequest < REQUEST_COOLDOWN then
		return
	end

	self.lastRequestAt[player] = now

	if type(codeInput) ~= "string" or #codeInput > MAX_INPUT_LENGTH then
		self:SendFeedback(player, "Enter a valid code.", false)

		return
	end

	local code: string = normalizeCode(codeInput)
	if code == "" or #code > MAX_CODE_LENGTH then
		self:SendFeedback(player, "Enter a valid code.", false)

		return
	end

	local reward: RedeemCodeConfig.Reward = RedeemCodeConfig.rewards[code]
	if not reward then
		self:SendFeedback(player, "Invalid code.", false)

		return
	end

	local serverData: any = self.path.controller.ServerData
	local profile: any = serverData and serverData:GetPlayerProfile(player) or nil
	local producer: any = profile and profile.producer or nil
	if not producer then
		self:SendFeedback(player, "Your data is still loading. Try again shortly.", false)

		return
	end

	local state: any = producer:getState()
	local playerState: any = state.player
	local redeemedCodes: any = playerState and playerState.redeemedCodes or nil
	if type(redeemedCodes) == "table" and redeemedCodes[code] ~= nil then
		self:SendFeedback(player, "You have already redeemed this code.", false)

		return
	end

	local money: number = tonumber(reward.money) or 0
	local offerName: string? = reward.offerName
	local ownedOffers: any = state.monetization and state.monetization.offers
	local serverMonetization: any = self.path.controller.ServerMonetization
	local offerGrantable: boolean = offerName == nil
		or GameConfig.core.monetizationOfferCreationAllowed
		or type(ownedOffers) == "table" and ownedOffers[offerName] ~= nil
	if
		type(producer.secureRedeemCode) ~= "function"
		or money > 0 and type(producer.secureAddMoney) ~= "function"
		or offerName ~= nil and (type(producer.secureAddOffer) ~= "function" or not serverMonetization)
		or not offerGrantable
	then
		Logger.warn(`RedeemCodeController cannot grant the reward of code "{code}"`)
		self:SendFeedback(player, "This code could not be redeemed right now.", false)

		return
	end

	producer.secureRedeemCode(code, DateTime.now().UnixTimestamp)

	if money > 0 then
		producer.secureAddMoney(money)
	end

	if offerName then
		-- grants the offer and runs its MonetizationExecs.offers hook with no receiptInfo, which marks a code grant
		local offerGranted: boolean, offerError: any =
			pcall(serverMonetization.GrantOffer, serverMonetization, player, producer, offerName, nil)
		if not offerGranted then
			Logger.warn(`RedeemCodeController could not fully grant offer "{offerName}" of code "{code}": {offerError}`)
		end
	end

	serverData:SyncPlayerProfile(player)

	local rewardTexts: { string } = {}
	if money > 0 then
		table.insert(rewardTexts, `+{ConvertCurrency.SuffixFormat(money)} money`)
	end

	if offerName then
		table.insert(rewardTexts, offerName)
	end

	local message: string = #rewardTexts > 0 and `Code redeemed! {table.concat(rewardTexts, " and ")}.`
		or "Code redeemed!"

	self:SendFeedback(player, message, true)
end

function RedeemCodeController:PlayerRemoving(player: Player): ()
	self.lastRequestAt[player] = nil
end

function RedeemCodeController:Init(): ()
	self.maid:DoCleaning()
	self.lastRequestAt = {}

	self.maid:GiveTask(REDEEM_CODE_BRIDGE:Connect(function(player: Player, codeInput: unknown): ()
		self:Redeem(player, codeInput)
	end))
end

return RedeemCodeController
