local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientData = require(ReplicatedStorage.client.modules.ClientData)
local CooldownManager = require(ReplicatedStorage.shared.modules.CooldownManager)
local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local GetBridge = require(ReplicatedStorage.util.Core.GetBridge)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Core.Logger)
local Maid = require(ReplicatedStorage.package.Maid)
local MonetizationConfig = require(ReplicatedStorage.shared.config.MonetizationConfig)

export type MonetizationPrompt = {
	ApplyAvailability: (self: MonetizationPrompt) -> (),
	Destroy: (self: MonetizationPrompt) -> (),
	GetActivationDistance: (self: MonetizationPrompt) -> number,
	UpdateActivationDistance: (self: MonetizationPrompt) -> (),
	UpdatePrice: (self: MonetizationPrompt) -> (),
	UpdateState: (self: MonetizationPrompt, state: any) -> (),
	UpdateStock: (self: MonetizationPrompt, remaining: unknown) -> (),
	new: (instance: Instance, path: InitializerTypes.ClientPath) -> MonetizationPrompt?,
	__index: MonetizationPrompt,
	offers: { string },
	baseActivationDistance: number,
	isGamePass: boolean,
	isOwned: boolean,
	isSoldOut: boolean,
	limitedItemKey: string?,
	productName: string,
	purchaseActionText: string,
	stockLoaded: boolean,
	tag: string,
	type: string,
	billboardGui: BillboardGui?,
	instance: Attachment,
	path: InitializerTypes.ClientPath,
	prompt: ProximityPrompt,
	maid: Maid.Maid,
}

local MonetizationPrompt: MonetizationPrompt = {} :: any
MonetizationPrompt.__index = MonetizationPrompt
MonetizationPrompt.tag = script.Name
MonetizationPrompt.type = "tag"

local DEFAULT_ACTION_TEXT: string = "Buy"
local DEFAULT_OBJECT_TEXT: string = "" -- ProximityPrompt ObjectText used without a PromptObjectText attribute
local GAME_PASS_ATTRIBUTE: string = "IsGamePass"
local OWNED_TEXT: string = "OWNED"
local PRICE_LABEL_NAME: string = "Price"
local PRODUCT_NAME_ATTRIBUTE: string = "ProductName"
local PROMPT_NAME: string = "PurchasePrompt"
local PURCHASE_COOLDOWN_KEY: string = "PromptPurchase" -- CooldownManager key shared by every client purchase request
local PURCHASE_COOLDOWN_SECONDS: number = 1 -- minimum seconds between two purchase requests
local ROBUX_ICON: string = utf8.char(0xE002)
local SOLD_OUT_TEXT: string = "SOLD OUT"
local STOCK_LOADING_TEXT: string = "..."

local MONETIZATION_BRIDGE: any = GetBridge("MonetizationPrompt") -- asks ServerMonetization to prompt the purchase

local function getProductId(productName: string, isGamePass: boolean): number?
	if isGamePass then
		return MonetizationConfig.passes[productName]
	end

	local product: any = MonetizationConfig.products[productName]
	if type(product) == "number" then
		return product
	end

	return type(product) == "table" and tonumber(product.id) or nil
end

local function getConfiguredOffers(productName: string, isGamePass: boolean): { string }
	if isGamePass then
		return {}
	end

	local product: any = MonetizationConfig.products[productName]
	local configuredOffers: any = type(product) == "table" and (product.offer or product.offers) or nil

	return type(configuredOffers) == "string" and { configuredOffers }
		or type(configuredOffers) == "table" and configuredOffers
		or {}
end

local function setText(label: TextLabel, value: string): ()
	label.Text = value

	local shadow: TextLabel? = label:FindFirstChild("Shadow") :: TextLabel?
	if shadow and shadow:IsA("TextLabel") then
		shadow.Text = value
	end
end

-- the prompt's own distance is the floor; a part or model wider than it raises the distance to its horizontal size
function MonetizationPrompt:GetActivationDistance(): number
	local parent: Instance = self.instance.Parent :: Instance
	if not parent then
		return self.baseActivationDistance
	end

	if parent:IsA("BasePart") then
		return math.max(self.baseActivationDistance, parent.Size.X, parent.Size.Z)
	end

	if parent:IsA("Model") then
		local size: Vector3 = parent:GetExtentsSize()

		return math.max(self.baseActivationDistance, size.X, size.Z)
	end

	return self.baseActivationDistance
end

function MonetizationPrompt:UpdateActivationDistance(): ()
	self.prompt.MaxActivationDistance = self:GetActivationDistance()
end

function MonetizationPrompt:ApplyAvailability(): ()
	local billboardGui: BillboardGui? = self.billboardGui
	if billboardGui then
		billboardGui.Enabled = true
	end

	if self.isOwned then
		self.prompt.ActionText = self.purchaseActionText
		self.prompt.Enabled = false

		local ownedPrice: TextLabel = billboardGui and billboardGui:FindFirstChild(PRICE_LABEL_NAME, true) :: any
		if ownedPrice and ownedPrice:IsA("TextLabel") then
			setText(ownedPrice, OWNED_TEXT)
		end

		return
	end

	local stockAvailable: boolean = not self.limitedItemKey or self.stockLoaded and not self.isSoldOut

	self.prompt.ActionText = if self.limitedItemKey
			and self.stockLoaded
			and self.isSoldOut
		then SOLD_OUT_TEXT
		else self.purchaseActionText
	self.prompt.Enabled = stockAvailable

	self:UpdatePrice()
end

function MonetizationPrompt:UpdateState(state: any): ()
	local monetizationState: any = state.monetization
	local ownsGamePass: boolean = self.isGamePass
			and monetizationState
			and monetizationState.passes
			and monetizationState.passes[self.productName] == true
		or false
	local ownsOffer: boolean = false
	for index: number = 1, #self.offers do
		if monetizationState and monetizationState.offers and monetizationState.offers[self.offers[index]] == true then
			ownsOffer = true

			break
		end
	end

	self.isOwned = ownsGamePass or ownsOffer

	self:ApplyAvailability()
end

function MonetizationPrompt:UpdateStock(remaining: unknown): ()
	if type(remaining) ~= "number" then
		return
	end

	self.stockLoaded = true
	self.isSoldOut = remaining <= 0

	self:ApplyAvailability()
end

function MonetizationPrompt:UpdatePrice(): ()
	local productId: number? = getProductId(self.productName, self.isGamePass)
	local billboardGui: BillboardGui? = self.billboardGui
	local priceLabel: TextLabel = billboardGui and billboardGui:FindFirstChild(PRICE_LABEL_NAME, true) :: any
	if not productId or not priceLabel or not priceLabel:IsA("TextLabel") then
		return
	end

	if self.isOwned then
		setText(priceLabel, OWNED_TEXT)

		return
	end

	if self.limitedItemKey and (not self.stockLoaded or self.isSoldOut) then
		setText(priceLabel, if self.stockLoaded then SOLD_OUT_TEXT else STOCK_LOADING_TEXT)

		return
	end

	local infoType: Enum.InfoType = self.isGamePass and Enum.InfoType.GamePass or Enum.InfoType.Product

	task.spawn(function(): ()
		local success: boolean, productInfo: any =
			pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, productId, infoType)
		local price: number? = success and productInfo and tonumber(productInfo.PriceInRobux) or nil
		if not price or price < 0 or not self.instance.Parent then
			return
		end

		if self.isOwned then
			setText(priceLabel, OWNED_TEXT)

			return
		end

		if self.limitedItemKey and (not self.stockLoaded or self.isSoldOut) then
			setText(priceLabel, if self.stockLoaded then SOLD_OUT_TEXT else STOCK_LOADING_TEXT)

			return
		end

		setText(priceLabel, `{ROBUX_ICON}{price}`)
	end)
end

function MonetizationPrompt.new(instance: Instance, path: InitializerTypes.ClientPath): MonetizationPrompt?
	if not instance:IsA("Attachment") then
		Logger.warn(`MonetizationPrompt tag requires an Attachment, got {instance:GetFullName()}`)

		return
	end

	local productName: unknown = instance:GetAttribute(PRODUCT_NAME_ATTRIBUTE)
	if typeof(productName) ~= "string" or productName == "" then
		Logger.warn(`MonetizationPrompt is missing {PRODUCT_NAME_ATTRIBUTE}: {instance:GetFullName()}`)

		return
	end

	local isGamePass: boolean = instance:GetAttribute(GAME_PASS_ATTRIBUTE) == true
	if not getProductId(productName, isGamePass) then
		Logger.warn(`MonetizationPrompt has unknown product {productName}: {instance:GetFullName()}`)

		return
	end

	local parent: Instance = instance.Parent :: Instance
	if not parent then
		Logger.warn(`MonetizationPrompt Attachment has no parent: {instance:GetFullName()}`)

		return
	end

	local actionText: unknown = instance:GetAttribute("PromptActionText")
	local objectText: unknown = instance:GetAttribute("PromptObjectText")
	local purchaseActionText: string = if typeof(actionText) == "string" then actionText else DEFAULT_ACTION_TEXT
	local promptCandidate: Instance? = instance:FindFirstChild(PROMPT_NAME)
	local prompt: ProximityPrompt
	local createdPrompt: boolean = false
	if promptCandidate and promptCandidate:IsA("ProximityPrompt") then
		prompt = promptCandidate
	else
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
		createdPrompt = true
	end

	prompt.ActionText = purchaseActionText
	prompt.HoldDuration = 0
	prompt.ObjectText = if typeof(objectText) == "string" then objectText else DEFAULT_OBJECT_TEXT
	prompt.RequiresLineOfSight = false

	if createdPrompt then
		prompt.Parent = instance
	end

	local limitedConfig: any = GameConfig.game.limitedItems[productName]

	local self: MonetizationPrompt = setmetatable({}, MonetizationPrompt) :: any
	self.baseActivationDistance = prompt.MaxActivationDistance -- an authored prompt's distance, else the default
	self.billboardGui = parent:FindFirstChildWhichIsA("BillboardGui")
	self.instance = instance
	self.isGamePass = isGamePass
	self.isOwned = false
	self.isSoldOut = false
	self.limitedItemKey = limitedConfig and limitedConfig.itemKey or nil
	self.maid = Maid.new()
	self.offers = getConfiguredOffers(productName, isGamePass)
	self.path = path
	self.productName = productName
	self.prompt = prompt
	self.purchaseActionText = purchaseActionText
	self.stockLoaded = limitedConfig == nil

	if parent:IsA("Model") then
		self.maid:GiveTask(parent.DescendantAdded:Connect(function(descendant: Instance): ()
			if descendant:IsA("BasePart") then
				self:UpdateActivationDistance()
			end
		end))
	end

	self:UpdateActivationDistance()

	self.maid:GiveTask(prompt.Triggered:Connect(function(playerWhoTriggered: Player): ()
		if
			playerWhoTriggered ~= Players.LocalPlayer
			or self.isOwned
			or self.limitedItemKey and (not self.stockLoaded or self.isSoldOut)
			or not CooldownManager:IsReady(PURCHASE_COOLDOWN_KEY)
		then
			return
		end

		CooldownManager:Set(PURCHASE_COOLDOWN_KEY, PURCHASE_COOLDOWN_SECONDS)

		MONETIZATION_BRIDGE:Fire({
			isGamePass = self.isGamePass,
			name = self.productName,
		})
	end))

	ClientData:GetPlayerProducerAsync():andThen(function(producer: any): ()
		if not self.instance.Parent then
			return
		end

		self.maid:GiveTask(producer:subscribe(function(state: any): any
			return state.monetization
		end, function(): ()
			self:UpdateState(producer:getState())
		end))

		self:UpdateState(producer:getState())
	end)

	if self.limitedItemKey then
		ClientData:GetGameProducerAsync():andThen(function(producer: any): ()
			if not self.instance.Parent then
				return
			end

			self.maid:GiveTask(producer:subscribe(function(state: any): number?
				return state.limitedItems and state.limitedItems[self.limitedItemKey :: string] or nil
			end, function(remaining: number?): ()
				self:UpdateStock(remaining)
			end))

			local state: any = producer:getState()

			self:UpdateStock(state.limitedItems and state.limitedItems[self.limitedItemKey :: string] or nil)
		end)
	end

	self:ApplyAvailability()

	return self
end

function MonetizationPrompt:Destroy(): ()
	self.maid:DoCleaning()

	self.prompt.Enabled = false
end

return MonetizationPrompt
