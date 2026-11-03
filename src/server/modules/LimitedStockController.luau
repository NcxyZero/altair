local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local GlobalStock = require(ServerScriptService.server.modules.class.GlobalStock)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Core.Logger)
local Maid = require(ReplicatedStorage.package.Maid)

type LimitedItemConfig = {
	amount: number,
	itemKey: string,
	stockName: string,
}

type Reservation = {
	cancelled: boolean,
	config: LimitedItemConfig,
	productName: string,
	purchaseConfirmed: boolean,
	reserved: boolean,
}

export type LimitedStockController = {
	CommitReservation: (self: LimitedStockController, player: Player, productName: string) -> boolean,
	CompletePurchase: (self: LimitedStockController, player: Player, productName: string) -> boolean,
	ConsumeUnreservedUnit: (self: LimitedStockController, config: LimitedItemConfig, productName: string) -> (),
	HasReservation: (self: LimitedStockController, player: Player, productName: string) -> boolean,
	Init: (self: LimitedStockController) -> (),
	IsLimitedProduct: (self: LimitedStockController, productName: string) -> boolean,
	PlayerRemoving: (self: LimitedStockController, player: Player) -> (),
	PublishRefresh: (self: LimitedStockController, config: LimitedItemConfig) -> (),
	QueueRefresh: (self: LimitedStockController, productName: string) -> (),
	RefreshProduct: (self: LimitedStockController, productName: string, ensureInitial: boolean?) -> number?,
	ReleaseReservation: (self: LimitedStockController, player: Player, productName: string?) -> boolean,
	ReserveProduct: (self: LimitedStockController, player: Player, productName: string) -> (boolean, string?),
	UpdateReplicatedStock: (self: LimitedStockController, config: LimitedItemConfig, remaining: number) -> (),
	prepaidUnits: { [string]: number },
	refreshQueued: { [string]: boolean },
	reservations: { [Player]: Reservation },
	index: number,
	type: string,
	stock: any,
	path: InitializerTypes.ServerPath,
	maid: Maid.Maid,
}

local LimitedStockController: LimitedStockController = {} :: any
LimitedStockController.index = 1
LimitedStockController.type = "controller"

local MESSAGE_TOPIC: string = "AltairLimitedStock_v1" -- MessagingService topic that asks servers to refresh a stock
local MESSAGE_REFRESH_DELAY_SECONDS: number = 5 -- delay before a server re-reads a stock after a refresh message
local POLL_INTERVAL_SECONDS: number = 15 -- interval between DataStore refreshes of every limited item

local function getLimitedConfig(productName: string): LimitedItemConfig?
	return GameConfig.game.limitedItems[productName]
end

local function getPrepaidKey(player: Player, productName: string): string
	return `{player.UserId}::{productName}`
end

function LimitedStockController:IsLimitedProduct(productName: string): boolean
	return getLimitedConfig(productName) ~= nil
end

function LimitedStockController:HasReservation(player: Player, productName: string): boolean
	local reservation: Reservation? = self.reservations[player]

	return reservation ~= nil and reservation.productName == productName and reservation.reserved
end

function LimitedStockController:UpdateReplicatedStock(config: LimitedItemConfig, remaining: number): ()
	local producer: any = self.path.controller.ServerData.gameProducer
	if not producer then
		return
	end

	local normalized: number = math.clamp(remaining // 1, 0, config.amount)
	local state: any = producer:getState()
	local current: any = state.limitedItems and state.limitedItems[config.itemKey]
	if current == normalized then
		return
	end

	producer.secureSetStock(config.itemKey, normalized)
end

function LimitedStockController:PublishRefresh(config: LimitedItemConfig): ()
	local success: boolean, errorMessage: any = pcall(function(): ()
		MessagingService:PublishAsync(MESSAGE_TOPIC, {
			itemKey = config.itemKey,
			stockName = config.stockName,
		})
	end)

	if not success then
		Logger.warn(`Limited stock refresh publish failed: {tostring(errorMessage)}`)
	end
end

function LimitedStockController:RefreshProduct(productName: string, ensureInitial: boolean?): number?
	local config: LimitedItemConfig? = getLimitedConfig(productName)
	if not config then
		return
	end

	local remaining: number? = self.stock:RefreshRemainingStockAmount(config.stockName, config.itemKey)
	if remaining == nil and ensureInitial then
		-- consuming 0 writes the full amount only into a missing counter and returns nil when the DataStore fails,
		-- unlike EnsureRemainingStockAmount, which caches and returns the full amount after a failed write
		remaining = self.stock:ConsumeRemainingStockAmount(config.stockName, config.itemKey, 0, config.amount)
	end

	if remaining == nil then
		return
	end

	self:UpdateReplicatedStock(config, remaining)

	return remaining
end

function LimitedStockController:QueueRefresh(productName: string): ()
	if self.refreshQueued[productName] then
		return
	end

	self.refreshQueued[productName] = true

	task.delay(MESSAGE_REFRESH_DELAY_SECONDS, function(): ()
		self.refreshQueued[productName] = nil
		self:RefreshProduct(productName, false)
	end)
end

function LimitedStockController:ReserveProduct(player: Player, productName: string): (boolean, string?)
	local config: LimitedItemConfig? = getLimitedConfig(productName)
	if not config then
		return false, "not_limited"
	end

	if not self.stock then
		return false, "unavailable"
	end

	if self.reservations[player] then
		return false, "purchase_pending"
	end

	local reservation: Reservation = {
		cancelled = false,
		config = config,
		productName = productName,
		purchaseConfirmed = false,
		reserved = false,
	}
	self.reservations[player] = reservation

	local accepted: boolean, remaining: number? =
		self.stock:TryConsumeRemainingStockAmount(config.stockName, config.itemKey, 1, config.amount)
	if remaining ~= nil then
		self:UpdateReplicatedStock(config, remaining)
	end

	if not accepted then
		if self.reservations[player] == reservation then
			self.reservations[player] = nil
		end

		return false, if remaining == nil then "unavailable" else "sold_out"
	end

	reservation.reserved = true

	self:PublishRefresh(config)

	if reservation.cancelled or not player:IsDescendantOf(game) then
		self:ReleaseReservation(player, productName)

		return false, "player_left"
	end

	return true, nil
end

function LimitedStockController:CommitReservation(player: Player, productName: string): boolean
	local reservation: Reservation? = self.reservations[player]
	if not reservation or reservation.productName ~= productName or not reservation.reserved then
		return false
	end

	reservation.purchaseConfirmed = true

	return true
end

-- Called after a limited product's receipt is granted. Returns true when a reservation or a released confirmed
-- reservation already took the unit; otherwise (a purchase prompted outside ServerMonetization) a fresh unit is taken.
function LimitedStockController:CompletePurchase(player: Player, productName: string): boolean
	local reservation: Reservation? = self.reservations[player]
	if reservation and reservation.productName == productName and reservation.reserved then
		self.reservations[player] = nil

		return true
	end

	local prepaidKey: string = getPrepaidKey(player, productName)
	local prepaid: number = self.prepaidUnits[prepaidKey] or 0
	if prepaid > 0 then
		self.prepaidUnits[prepaidKey] = if prepaid > 1 then prepaid - 1 else nil

		return true
	end

	local config: LimitedItemConfig? = getLimitedConfig(productName)
	if config and self.stock then
		task.spawn(self.ConsumeUnreservedUnit, self, config, productName)
	end

	return false
end

function LimitedStockController:ConsumeUnreservedUnit(config: LimitedItemConfig, productName: string): ()
	local accepted: boolean, remaining: number? =
		self.stock:TryConsumeRemainingStockAmount(config.stockName, config.itemKey, 1, config.amount)
	if remaining == nil then
		Logger.warn(`Limited stock: could not take a unit for {productName}, bought without a reservation`)

		return
	end

	self:UpdateReplicatedStock(config, remaining)

	if not accepted then
		Logger.warn(`Limited stock: {productName} was oversold, bought without a reservation while sold out`)

		return
	end

	self:PublishRefresh(config)
end

function LimitedStockController:ReleaseReservation(player: Player, productName: string?): boolean
	local reservation: Reservation? = self.reservations[player]
	if not reservation or productName ~= nil and reservation.productName ~= productName then
		return false
	end

	if reservation.purchaseConfirmed then
		self.reservations[player] = nil

		-- the unit stays taken; remembered so the retried receipt of this purchase does not take a second one
		local prepaidKey: string = getPrepaidKey(player, reservation.productName)
		self.prepaidUnits[prepaidKey] = (self.prepaidUnits[prepaidKey] or 0) + 1

		return true
	end

	reservation.cancelled = true

	if not reservation.reserved then
		return true
	end

	self.reservations[player] = nil

	local config: LimitedItemConfig = reservation.config
	local remaining: number? =
		self.stock:RestoreRemainingStockAmount(config.stockName, config.itemKey, 1, config.amount)
	if remaining ~= nil then
		self:UpdateReplicatedStock(config, remaining)
		self:PublishRefresh(config)
	end

	return remaining ~= nil
end

function LimitedStockController:PlayerRemoving(player: Player): ()
	self:ReleaseReservation(player, nil)
end

function LimitedStockController:Init(): ()
	self.maid = Maid.new()
	self.prepaidUnits = {}
	self.reservations = {}
	self.refreshQueued = {}

	if next(GameConfig.game.limitedItems) == nil then
		return
	end

	self.stock = GlobalStock.new()

	task.spawn(function(): ()
		local subscribeSuccess: boolean, connectionOrError: any = pcall(function(): any
			return MessagingService:SubscribeAsync(MESSAGE_TOPIC, function(message: any): ()
				local data: any = message and message.Data
				if type(data) ~= "table" then
					return
				end

				for productName: string, config: LimitedItemConfig in GameConfig.game.limitedItems do
					if data.stockName == config.stockName and data.itemKey == config.itemKey then
						self:QueueRefresh(productName)

						return
					end
				end
			end)
		end)
		if subscribeSuccess then
			self.maid:GiveTask(connectionOrError)
		else
			Logger.warn(`Limited stock messaging subscription failed: {tostring(connectionOrError)}`)
		end
	end)

	for productName: string, _config: LimitedItemConfig in GameConfig.game.limitedItems do
		task.spawn(function(): ()
			self:RefreshProduct(productName, true)
		end)
	end

	task.spawn(function(): ()
		while true do
			task.wait(POLL_INTERVAL_SECONDS)

			for productName: string, _config: LimitedItemConfig in GameConfig.game.limitedItems do
				self:RefreshProduct(productName, true)
			end
		end
	end)
end

return LimitedStockController
