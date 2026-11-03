local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientData = require(ReplicatedStorage.client.modules.ClientData)
local CooldownManager = require(ReplicatedStorage.shared.modules.CooldownManager)
local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local GetBridge = require(ReplicatedStorage.util.Core.GetBridge)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)
local MonetizationConfig = require(ReplicatedStorage.shared.config.MonetizationConfig)

export type MonetizationButton = {
	ApplyLimitedAvailability: (self: MonetizationButton) -> (),
	Destroy: (self: MonetizationButton) -> (),
	SubscribeOwnership: (self: MonetizationButton) -> (),
	UpdateOwnedVisibility: (self: MonetizationButton, state: any) -> (),
	UpdatePrice: (self: MonetizationButton) -> (),
	UpdateStock: (self: MonetizationButton, remaining: unknown) -> (),
	new: (instance: GuiButton, path: InitializerTypes.ClientPath) -> MonetizationButton?,
	__index: MonetizationButton,
	offers: { string },
	hideOnComplete: boolean,
	hideWhenOwned: boolean,
	isGamePass: boolean,
	isOwned: boolean,
	isSoldOut: boolean,
	keepVisibleWhenOwned: boolean,
	limitedItemKey: string?,
	ownershipHidden: boolean,
	productName: string?,
	stockLoaded: boolean,
	tag: string,
	type: string,
	variantName: string?,
	button: GuiButton,
	hideTarget: GuiObject?,
	path: InitializerTypes.ClientPath,
	maid: Maid.Maid,
}

local MonetizationButton: MonetizationButton = {} :: any
MonetizationButton.__index = MonetizationButton
MonetizationButton.type = "local_tag"
MonetizationButton.tag = script.Name

local PRODUCT_ATTR: string = "ProductName"
local PRODUCT_ATTR_ALT: string = "Product"
local VARIANT_ATTR: string = "ProductVariantName"
local GAMEPASS_ATTR: string = "IsGamePass"
local OFFER_ATTR: string = "Offers"
local OFFER_ATTR_ALT: string = "OfferNames"
local HIDE_ON_COMPLETE_ATTR: string = "HideOnComplete"
local HIDE_OBJECT_VALUE_NAME: string = "HideObjectValue"
local KEEP_VISIBLE_WHEN_OWNED_ATTR: string = "KeepVisibleWhenOwned" -- keeps an owned button visible with the owned look
local PRICE_PREFIX_ATTR: string = "PricePrefix" -- price label attribute with the text written before the price
local BUTTON_ANIMATION_TAG: string = "ButtonAnimation"
local FOREGROUND_IMAGE_NAME: string = "ForegroundImage"
local FOREGROUND_TEXT_NAME: string = "ForegroundText"
local OWNED_BUTTON_COLOR: Color3 = Color3.fromRGB(128, 128, 128)
local OWNED_TEXT: string = "OWNED"
local PURCHASE_COOLDOWN_KEY: string = "PromptPurchase" -- CooldownManager key shared by every client purchase request
local PURCHASE_COOLDOWN_SECONDS: number = 1 -- minimum seconds between two purchase requests
local SOLD_OUT_TEXT: string = "SOLD OUT"
local STOCK_LOADING_TEXT: string = "..."
local ROBUX_ICON: string = utf8.char(0xE002)
local SHINE_ANIMATION_TAG: string = "ShineAnimation"

local function setText(label: TextLabel, value: string): ()
	label.Text = value

	local shadow: Instance? = label:FindFirstChild("Shadow")
		or label:FindFirstChild("PriceShadow")
		or label:FindFirstChild("ShadowText")
	if shadow and shadow:IsA("TextLabel") then
		shadow.Text = value
	end

	local foreground: TextLabel? = label:FindFirstChild(FOREGROUND_TEXT_NAME) :: TextLabel?
	if foreground and foreground:IsA("TextLabel") then
		foreground.Text = value
	end
end

local function getProductId(productName: string, variantName: string?, isGamePass: boolean): number?
	if isGamePass then
		return MonetizationConfig.passes[productName]
	end

	local product: any = MonetizationConfig.products[productName]
	if type(product) == "number" then
		return product
	end

	if type(product) ~= "table" then
		return
	end

	local productData: any = variantName and product.data and product.data[variantName] or product

	return type(productData) == "table" and tonumber(productData.id) or nil
end

local function resolveHideTarget(instance: GuiButton): GuiObject
	local objectValue: ObjectValue? = instance:FindFirstChild(HIDE_OBJECT_VALUE_NAME) :: ObjectValue?
	if objectValue then
		local value: Instance? = objectValue.Value
		if value and value:IsA("GuiObject") then
			return value
		end
	end

	return instance
end

local function parseOffersAttribute(instance: GuiButton): { string }?
	local raw: any = instance:GetAttribute(OFFER_ATTR)
	if typeof(raw) ~= "string" then
		raw = instance:GetAttribute(OFFER_ATTR_ALT)
	end

	if typeof(raw) ~= "string" then
		return
	end

	local parsed: { string } = {}
	local parts: { string } = raw:split(",")

	for index: number = 1, #parts do
		local trimmed: string = parts[index]:gsub("^%s+", ""):gsub("%s+$", "")
		if trimmed ~= "" then
			table.insert(parsed, trimmed)
		end
	end

	if #parsed == 0 then
		return
	end

	return parsed
end

-- offers ServerMonetization grants with the product: the variant entry's offer/offers, otherwise the group's
local function getConfiguredOffers(productName: string, variantName: string?, isGamePass: boolean): { string }
	local product: any = not isGamePass and MonetizationConfig.products[productName] or nil
	if type(product) ~= "table" then
		return {}
	end

	local entry: any = variantName and type(product.data) == "table" and product.data[variantName] or nil
	local configuredOffers: any = type(entry) == "table" and (entry.offer or entry.offers)
		or product.offer
		or product.offers

	return type(configuredOffers) == "string" and { configuredOffers }
		or type(configuredOffers) == "table" and configuredOffers
		or {}
end

local function mergeOffers(attributeOffers: { string }?, configuredOffers: { string }): { string }
	local offers: { string } = table.clone(attributeOffers or {})

	for _index: number, offerName: string in configuredOffers do
		if not table.find(offers, offerName) then
			table.insert(offers, offerName)
		end
	end

	return offers
end

local function hideTargetObject(target: GuiObject?): ()
	if target and target:IsA("GuiObject") then
		target.Visible = false
	end
end

local function showTargetObject(target: GuiObject?): ()
	if target and target:IsA("GuiObject") then
		target.Visible = true
	end
end

local function getPriceText(button: GuiButton): TextLabel?
	local candidate: Instance? = button:FindFirstChild("PriceText", true) or button:FindFirstChild("Price", true)

	return candidate and candidate:IsA("TextLabel") and candidate or nil
end

local function setOwnedButtonAppearance(button: GuiButton): ()
	button.Active = false
	button.BackgroundColor3 = OWNED_BUTTON_COLOR
	button.Interactable = false
	button.Selectable = false

	CollectionService:RemoveTag(button, BUTTON_ANIMATION_TAG)
	CollectionService:RemoveTag(button, SHINE_ANIMATION_TAG)

	if button:IsA("ImageButton") then
		button.ImageColor3 = OWNED_BUTTON_COLOR

		local foregroundImage: ImageLabel? = button:FindFirstChild(FOREGROUND_IMAGE_NAME) :: ImageLabel?
		if foregroundImage and foregroundImage:IsA("ImageLabel") then
			foregroundImage.ImageColor3 = OWNED_BUTTON_COLOR
		end
	end

	for _index: number, descendant: Instance in button:GetDescendants() do
		if descendant:IsA("UIGradient") then
			descendant.Enabled = false
		elseif descendant:IsA("Frame") and descendant.Name == "Background" then
			descendant.BackgroundColor3 = OWNED_BUTTON_COLOR
		end
	end

	local priceText: TextLabel? = getPriceText(button)
	if priceText then
		setText(priceText, OWNED_TEXT)
	end
end

function MonetizationButton:ApplyLimitedAvailability(): ()
	if not self.limitedItemKey or self.isOwned then
		return
	end

	local available: boolean = self.stockLoaded and not self.isSoldOut

	self.button.Active = available
	self.button.Interactable = available
	self.button.Selectable = available

	if available then
		self:UpdatePrice()

		return
	end

	local priceText: TextLabel? = getPriceText(self.button)
	if priceText then
		setText(priceText, if self.stockLoaded then SOLD_OUT_TEXT else STOCK_LOADING_TEXT)
	end
end

function MonetizationButton:UpdatePrice(): ()
	local priceText: TextLabel = getPriceText(self.button) :: TextLabel
	if not priceText then
		return
	end

	if self.isOwned then
		setText(priceText, OWNED_TEXT)

		return
	end

	if self.limitedItemKey and (not self.stockLoaded or self.isSoldOut) then
		setText(priceText, if self.stockLoaded then SOLD_OUT_TEXT else STOCK_LOADING_TEXT)

		return
	end

	local productName: string = self.productName :: string
	local productId: number = getProductId(productName, self.variantName, self.isGamePass) :: number
	if not productId then
		return
	end

	local infoType: Enum.InfoType = self.isGamePass and Enum.InfoType.GamePass or Enum.InfoType.Product

	task.spawn(function(): ()
		local success: boolean, productInfo: any =
			pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, productId, infoType)
		local price: number? = success and productInfo and tonumber(productInfo.PriceInRobux) or nil
		if not price or price < 0 or not self.button.Parent then
			return
		end

		if self.isOwned then
			setText(priceText, OWNED_TEXT)

			return
		end

		if self.limitedItemKey and (not self.stockLoaded or self.isSoldOut) then
			setText(priceText, if self.stockLoaded then SOLD_OUT_TEXT else STOCK_LOADING_TEXT)

			return
		end

		local prefixAttribute: unknown = priceText:GetAttribute(PRICE_PREFIX_ATTR)
		local prefix: string = if typeof(prefixAttribute) == "string" then prefixAttribute else ""

		setText(priceText, `{prefix}{ROBUX_ICON}{price}`)
	end)
end

function MonetizationButton:UpdateOwnedVisibility(state: any): ()
	local monetizationState: any = state.monetization
	local isOwned: boolean = self.isGamePass
			and monetizationState
			and monetizationState.passes
			and monetizationState.passes[self.productName] == true
		or false

	local offers: { string } = self.offers
	for index: number = 1, #offers do
		local ownsOffer: boolean = monetizationState
			and monetizationState.offers
			and monetizationState.offers[offers[index]] == true
		if ownsOffer then
			isOwned = true

			break
		end
	end

	self.isOwned = isOwned

	if isOwned and self.hideWhenOwned then
		self.ownershipHidden = true

		hideTargetObject(self.hideTarget)

		return
	end

	if isOwned then
		setOwnedButtonAppearance(self.button)

		return
	end

	-- only undoes a hide made for ownership; a hide after a completed purchase stays for the session
	if self.ownershipHidden then
		self.ownershipHidden = false

		showTargetObject(self.hideTarget)
	end

	self:ApplyLimitedAvailability()
end

function MonetizationButton:SubscribeOwnership(): ()
	ClientData:GetPlayerProducerAsync():andThen(function(producer: any): ()
		if not self.button.Parent or not CollectionService:HasTag(self.button, MonetizationButton.tag) then
			return
		end

		self.maid:GiveTask(producer:subscribe(function(state: any): any
			return state.monetization
		end, function(_monetizationState: any): ()
			self:UpdateOwnedVisibility(producer:getState())
		end))

		self:UpdateOwnedVisibility(producer:getState())
	end)
end

function MonetizationButton:UpdateStock(remaining: unknown): ()
	if type(remaining) ~= "number" then
		return
	end

	self.stockLoaded = true
	self.isSoldOut = remaining <= 0

	self:ApplyLimitedAvailability()
end

function MonetizationButton.new(instance: GuiButton, path: InitializerTypes.ClientPath): MonetizationButton?
	local self: MonetizationButton = setmetatable({}, MonetizationButton) :: any
	self.button = instance
	self.path = path
	self.maid = Maid.new()

	local productName: any = instance:GetAttribute(PRODUCT_ATTR)
	if typeof(productName) ~= "string" then
		productName = instance:GetAttribute(PRODUCT_ATTR_ALT)
	end

	if typeof(productName) ~= "string" then
		self.maid:DoCleaning()

		return
	end

	local limitedConfig: any = GameConfig.game.limitedItems[productName]
	local variantName: unknown = instance:GetAttribute(VARIANT_ATTR)

	self.productName = productName
	self.variantName = if typeof(variantName) == "string" then variantName else nil
	self.isGamePass = instance:GetAttribute(GAMEPASS_ATTR) == true
	self.limitedItemKey = limitedConfig and limitedConfig.itemKey or nil
	self.offers =
		mergeOffers(parseOffersAttribute(instance), getConfiguredOffers(productName, self.variantName, self.isGamePass))
	self.hideOnComplete = instance:GetAttribute(HIDE_ON_COMPLETE_ATTR) == true
	self.hideTarget = resolveHideTarget(instance)
	self.isOwned = false
	self.isSoldOut = false
	self.keepVisibleWhenOwned = instance:GetAttribute(KEEP_VISIBLE_WHEN_OWNED_ATTR) == true
	self.hideWhenOwned = self.hideOnComplete and not self.keepVisibleWhenOwned
	self.ownershipHidden = false
	self.stockLoaded = limitedConfig == nil

	local bridge: any = GetBridge("MonetizationPrompt")

	if self.isGamePass or #self.offers > 0 then
		-- a button that hides when owned stays hidden until the first ownership update, so it never flashes
		if self.hideWhenOwned then
			self.ownershipHidden = true

			hideTargetObject(self.hideTarget)
		end

		self:SubscribeOwnership()
	end

	if self.limitedItemKey then
		self:ApplyLimitedAvailability()

		ClientData:GetGameProducerAsync():andThen(function(producer: any): ()
			if not self.button.Parent then
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

	self:UpdatePrice()

	if self.hideOnComplete then
		self.maid:GiveTask(bridge:Connect(function(data: {
			name: string,
			isGamePass: boolean?,
			productName: string?,
			completed: boolean?,
			success: boolean?,
		} | any): ()
			if self.keepVisibleWhenOwned then
				return
			end

			if typeof(data) ~= "table" then
				return
			end

			if data.completed ~= true or data.success ~= true then
				return
			end

			if data.name ~= self.productName then
				return
			end

			local dataProductName: any = data.productName
			if self.variantName ~= dataProductName then
				return
			end

			local dataIsGamePass: boolean = data.isGamePass == true
			if dataIsGamePass ~= self.isGamePass then
				return
			end

			local target: GuiObject? = self.hideTarget
			if target and target:IsA("GuiObject") then
				target.Visible = false
			end
		end))
	end

	self.maid:GiveTask(instance.MouseButton1Down:Connect(function(): ()
		if
			self.isOwned
			or self.limitedItemKey and (not self.stockLoaded or self.isSoldOut)
			or not CooldownManager:IsReady(PURCHASE_COOLDOWN_KEY)
		then
			return
		end

		CooldownManager:Set(PURCHASE_COOLDOWN_KEY, PURCHASE_COOLDOWN_SECONDS)

		bridge:Fire({
			name = self.productName,
			isGamePass = self.isGamePass,
			productName = self.variantName,
		})
	end))

	return self
end

function MonetizationButton:Destroy(): ()
	self.maid:DoCleaning()
end

return MonetizationButton
