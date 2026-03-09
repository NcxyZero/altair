local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientData = require(ReplicatedStorage.client.modules.ClientData)
local GetBridge = require(ReplicatedStorage.util.GetBridge)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)

export type MonetizationButton = {
	button: GuiButton,
	maid: Maid.Maid,
	path: InitializerTypes.ClientPath,
	productName: string?,
	variantName: string?,
	offers: { string }?,
	hideTarget: GuiObject?,
	hideOnComplete: boolean,
	isGamePass: boolean,
	type: string,
	tag: string,
	__index: MonetizationButton,
	new: (instance: GuiButton, path: InitializerTypes.ClientPath) -> MonetizationButton?,
	Destroy: (self: MonetizationButton) -> (),
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

function MonetizationButton.new(instance: GuiButton, path: InitializerTypes.ClientPath): MonetizationButton?
	local self = setmetatable({}, MonetizationButton)
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

	self.productName = productName
	self.variantName = typeof(instance:GetAttribute(VARIANT_ATTR)) == "string" and instance:GetAttribute(VARIANT_ATTR)
		or nil
	self.isGamePass = instance:GetAttribute(GAMEPASS_ATTR) == true
	self.offers = parseOffersAttribute(instance)
	self.hideOnComplete = instance:GetAttribute(HIDE_ON_COMPLETE_ATTR) == true
	self.hideTarget = resolveHideTarget(instance)

	if self.offers then
		hideTargetObject(self.hideTarget)
	end

	local function tryHideOwnedOffers(): ()
		local offers: { string }? = self.offers
		if not offers then
			return
		end

		local producer = ClientData:GetPlayerProducerAsync():expect()
		local state = producer:getState()

		for index: number = 1, #offers do
			local offerName: string = offers[index]
			local owned: boolean = state.monetization
				and state.monetization.offers
				and state.monetization.offers[offerName]
			if owned then
				hideTargetObject(self.hideTarget)

				return
			end
		end

		showTargetObject(self.hideTarget)
	end

	local offersSubscriptionMaid: Maid.Maid = nil
	local function subscribeOffers(): ()
		local offers: { string }? = self.offers
		if not offers then
			return
		end

		local producer = ClientData:GetPlayerProducerAsync():expect()
		offersSubscriptionMaid = Maid.new()
		self.maid:GiveTask(offersSubscriptionMaid)

		local function handleState(state: any): ()
			for index: number = 1, #offers do
				local offerName: string = offers[index]
				local owned: boolean = state.monetization
					and state.monetization.offers
					and state.monetization.offers[offerName]
				if owned then
					hideTargetObject(self.hideTarget)

					return
				end
			end

			showTargetObject(self.hideTarget)
		end

		offersSubscriptionMaid:GiveTask(producer:subscribe(function(state): any
			return state.monetization and state.monetization.offers
		end, handleState))

		handleState(producer:getState())
	end

	local bridge: any = GetBridge("MonetizationPrompt")

	tryHideOwnedOffers()
	subscribeOffers()

	if self.hideOnComplete then
		self.maid:GiveTask(
			bridge:Connect(
				function(
					data: { name: string, isGamePass: boolean?, productName: string?, completed: boolean? } | any
				): ()
					if typeof(data) ~= "table" then
						return
					end

					if data.completed ~= true then
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
				end
			)
		)
	end

	self.maid:GiveTask(instance.MouseButton1Down:Connect(function(): ()
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
