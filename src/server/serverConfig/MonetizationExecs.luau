local ReplicatedStorage = game:GetService("ReplicatedStorage")

local APIDictionaries = require(ReplicatedStorage.shared.types.APIDictionaries)
local Logger = require(ReplicatedStorage.util.Core.Logger)

local MonetizationExecs = {
	-- keyed by offer name; runs after the offer is granted, with receiptInfo = nil when a redeem code granted it
	offers = {
		starterPack = function(_player: Player, _offerName: string, _receiptInfo: APIDictionaries.receiptInfo?): ()
			Logger.print("starterPack executed")
		end,
	},
	-- returning false rejects the receipt and Roblox retries it, so keep execs idempotent per PurchaseId
	execs = {
		Exec1 = function(
			_player: Player,
			_data: { name: string, dataName: string? },
			_config: any,
			_receiptInfo: APIDictionaries.receiptInfo
		): boolean
			Logger.print("Exec1 executed")

			return true
		end,
	},
}

return MonetizationExecs
