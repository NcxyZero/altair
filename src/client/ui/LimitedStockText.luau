local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientData = require(ReplicatedStorage.client.modules.ClientData)
local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Core.Logger)
local Maid = require(ReplicatedStorage.package.Maid)

export type LimitedStockText = {
	Destroy: (self: LimitedStockText) -> (),
	SetRemaining: (self: LimitedStockText, remaining: number) -> (),
	new: (instance: Instance, path: InitializerTypes.ClientPath) -> LimitedStockText?,
	__index: LimitedStockText,
	itemKey: string,
	maximum: number,
	suffix: string,
	tag: string,
	type: string,
	instance: TextLabel,
	path: InitializerTypes.ClientPath,
	maid: Maid.Maid,
}

local LimitedStockText: LimitedStockText = {} :: any
LimitedStockText.__index = LimitedStockText
LimitedStockText.tag = script.Name
LimitedStockText.type = "tag"

local ITEM_KEY_ATTRIBUTE: string = "LimitedItemKey" -- GameConfig.game.limitedItems key (product name) to display
local STOCK_LOADING_TEXT: string = "..." -- shown instead of the remaining count until the server replicates it
local SUFFIX_ATTRIBUTE: string = "LimitedStockSuffix" -- optional text appended after "remaining/maximum"

-- child TextLabels that mirror the label text
local TEXT_LAYER_NAMES: { string } = {
	"NameText",
	"ForegroundText",
	"Shadow",
}

local function setLayeredText(label: TextLabel, text: string): ()
	label.Text = text

	for index: number = 1, #TEXT_LAYER_NAMES do
		local layer: Instance? = label:FindFirstChild(TEXT_LAYER_NAMES[index])
		if layer and layer:IsA("TextLabel") then
			layer.Text = text
		end
	end
end

function LimitedStockText:SetRemaining(remaining: number): ()
	local normalized: number = math.clamp((tonumber(remaining) or 0) // 1, 0, self.maximum)

	setLayeredText(self.instance, `{normalized}/{self.maximum}{self.suffix}`)
end

function LimitedStockText.new(instance: Instance, path: InitializerTypes.ClientPath): LimitedStockText?
	if not instance:IsA("TextLabel") then
		Logger.warn(`LimitedStockText tag requires a TextLabel, got {instance:GetFullName()}`)

		return
	end

	local limitedKey: unknown = instance:GetAttribute(ITEM_KEY_ATTRIBUTE)
	local config: any = typeof(limitedKey) == "string" and GameConfig.game.limitedItems[limitedKey] or nil
	if not config then
		Logger.warn(`LimitedStockText has unknown {ITEM_KEY_ATTRIBUTE}: {instance:GetFullName()}`)

		return
	end

	local suffixAttribute: unknown = instance:GetAttribute(SUFFIX_ATTRIBUTE)

	local self: LimitedStockText = setmetatable({}, LimitedStockText) :: any
	self.instance = instance
	self.itemKey = config.itemKey
	self.maximum = math.max(0, config.amount // 1)
	self.suffix = typeof(suffixAttribute) == "string" and suffixAttribute or ""
	self.path = path
	self.maid = Maid.new()

	setLayeredText(self.instance, `{STOCK_LOADING_TEXT}/{self.maximum}{self.suffix}`)

	ClientData:GetGameProducerAsync():andThen(function(producer: any): ()
		if not self.instance.Parent or not CollectionService:HasTag(self.instance, LimitedStockText.tag) then
			return
		end

		self.maid:GiveTask(producer:subscribe(function(state: any): number?
			return state.limitedItems and state.limitedItems[self.itemKey] or nil
		end, function(remaining: number?): ()
			if remaining ~= nil then
				self:SetRemaining(remaining)
			end
		end))

		local state: any = producer:getState()
		local remaining: any = state.limitedItems and state.limitedItems[self.itemKey]
		if type(remaining) == "number" then
			self:SetRemaining(remaining)
		end
	end)

	return self
end

function LimitedStockText:Destroy(): ()
	self.maid:DoCleaning()
end

return LimitedStockText
