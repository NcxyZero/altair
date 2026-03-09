local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local APIDictionaries = require(ReplicatedStorage.shared.types.APIDictionaries)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local LocalPlayer = require(ReplicatedStorage.util.LocalPlayer)
local Logger = require(ReplicatedStorage.util.Logger)
local Maid = require(ReplicatedStorage.package.Maid)

export type BuyDevProduct = {
	__index: BuyDevProduct,
	instance: GuiButton,
	maid: Maid.Maid,
	path: InitializerTypes.ClientPath,
	tag: string,
	type: string,
	Destroy: (self: BuyDevProduct) -> (),
	PromptPurchase: (self: BuyDevProduct) -> (),
	UpdatePriceText: (self: BuyDevProduct) -> (),
	new: (instance: GuiButton, path: InitializerTypes.ClientPath) -> BuyDevProduct,
}

local BuyDevProduct: BuyDevProduct = {} :: any
BuyDevProduct.__index = BuyDevProduct
BuyDevProduct.type = "local_tag"
BuyDevProduct.tag = script.Name

local ID_ATTRIBUTE: string = "id"

local function findPriceText(instance: Instance): TextLabel?
	local priceContainer: Instance? = instance:FindFirstChild("Price")
	if not priceContainer then
		return
	end

	local priceText: Instance? = priceContainer:FindFirstChild("PriceText")
	if not priceText or not priceText:IsA("TextLabel") then
		return
	end

	return priceText
end

function BuyDevProduct:UpdatePriceText(): ()
	local priceText: TextLabel? = findPriceText(self.instance)
	if not priceText then
		return
	end

	local id: any = self.instance:GetAttribute(ID_ATTRIBUTE)
	if type(id) ~= "number" or id <= 0 then
		priceText.Text = "0"

		return
	end

	local succ: boolean, marketplaceData: APIDictionaries.MarketplaceProductInfo = xpcall(
		function(): APIDictionaries.MarketplaceProductInfo
			return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Product) :: any
		end,
		Logger.warn
	)

	local priceInRobux: number = 0
	priceInRobux = (succ and marketplaceData and marketplaceData.PriceInRobux) or priceInRobux
	priceText.Text = tostring(priceInRobux)
end

function BuyDevProduct:PromptPurchase(): ()
	local id: any = self.instance:GetAttribute(ID_ATTRIBUTE)
	if type(id) ~= "number" or id <= 0 then
		return
	end

	MarketplaceService:PromptProductPurchase(LocalPlayer, id)
end

function BuyDevProduct.new(instance: GuiButton, path: InitializerTypes.ClientPath): BuyDevProduct
	local self = setmetatable({}, BuyDevProduct)
	self.instance = instance
	self.path = path
	self.maid = Maid.new()

	instance.Selectable = true

	self.maid:GiveTask(instance.MouseButton1Down:Connect(function(): ()
		self:PromptPurchase()
	end))

	self.maid:GiveTask(instance:GetAttributeChangedSignal(ID_ATTRIBUTE):Connect(function(): ()
		self:UpdatePriceText()
	end))

	self:UpdatePriceText()

	return self
end

function BuyDevProduct:Destroy(): ()
	self.maid:DoCleaning()
end

return BuyDevProduct
