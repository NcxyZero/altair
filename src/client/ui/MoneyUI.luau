local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ClientData = require(ReplicatedStorage.client.modules.ClientData)
local ConvertCurrency = require(ReplicatedStorage.util.ConvertCurrency)
local EffectGuiConfig = require(ReplicatedStorage.shared.config.EffectGuiConfig)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)

export type Default = {
	closeButtons: { GuiObject }?,
	openButtons: { GuiObject }?,
	toggleButtons: { GuiObject }?,
	baseSize: UDim2,
	instance: TextLabel,
	lastAmount: number?,
	moneyChangeEnabled: boolean?,
	moneyChangeContainer: Frame?,
	prefix: string,
	currencyKey: string,
	maid: Maid.Maid,
	tweensMaid: Maid.Maid,
	path: InitializerTypes.ClientPath,
	tag: string,
	type: string,
	__index: Default,
	new: (instance: TextLabel, path: InitializerTypes.ClientPath) -> Default,
	ShowMoneyChange: (self: Default, difference: number) -> (),
	PlayMoneyPulseEffect: (self: Default) -> (),
	Destroy: (self: Default) -> (),
}

local MoneyCounter: Default = {} :: Default
MoneyCounter.__index = MoneyCounter
MoneyCounter.type = "local_tag"
MoneyCounter.tag = script.Name

local CHANGE_FADE_DELAY: number = 3
local CHANGE_FADE_TWEEN_INFO: TweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local DISABLE_MONEY_CHANGE_INDICATOR_ATTR: string = "DisableMoneyChangeIndicator"
local NO_PREFIX_ATTR: string = "NoPrefix"
local CURRENCY_ATTR: string = "Currency"

local DEFAULT_PREFIXES = {
	money = "$",
	diamonds = "💎",
}

local POSITIVE_GRADIENT: ColorSequence = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(29, 216, 0)),
	ColorSequenceKeypoint.new(0.521589, Color3.fromRGB(56, 205, 4)),
	ColorSequenceKeypoint.new(0.607945, Color3.fromRGB(61, 181, 6)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(83, 193, 9)),
})

local NEGATIVE_GRADIENT: ColorSequence = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(234, 44, 19)),
	ColorSequenceKeypoint.new(0.528497, Color3.fromRGB(224, 57, 25)),
	ColorSequenceKeypoint.new(0.620035, Color3.fromRGB(172, 44, 21)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(216, 68, 31)),
})

function MoneyCounter.new(instance: TextLabel, path: InitializerTypes.ClientPath): Default
	local self = setmetatable({}, MoneyCounter)
	self.instance = instance
	self.path = path

	self.maid = Maid.new()
	self.tweensMaid = Maid.new()

	self.baseSize = instance.Size

	local currencyAttr: any = instance:GetAttribute(CURRENCY_ATTR)
	local currencyKey: string = "money"

	if typeof(currencyAttr) == "string" then
		currencyKey = currencyAttr:lower()
	end

	self.currencyKey = currencyKey

	self.prefix = instance:GetAttribute(NO_PREFIX_ATTR) and "" or DEFAULT_PREFIXES[currencyKey] or ""
	self.moneyChangeDisabled = instance:GetAttribute(DISABLE_MONEY_CHANGE_INDICATOR_ATTR)

	if not self.moneyChangeDisabled then
		local changeContainer: Frame = Instance.new("Frame")
		changeContainer.Name = "MoneyChangeContainer"
		changeContainer.AnchorPoint = Vector2.one * 0.5
		changeContainer.BackgroundTransparency = 1
		changeContainer.Position = instance.Position
		changeContainer.Size = instance.Size
		changeContainer.ZIndex = instance.ZIndex + 1

		local listLayout: UIListLayout = Instance.new("UIListLayout")
		listLayout.Name = "MoneyChangeLayout"
		listLayout.FillDirection = Enum.FillDirection.Vertical
		listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		listLayout.Padding = UDim.new(0, 2)
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		listLayout.Parent = changeContainer

		changeContainer.Parent = instance.Parent

		self.moneyChangeContainer = changeContainer
		self.moneyChangeEnabled = true

		self.maid:GiveTask(changeContainer)
	else
		self.moneyChangeEnabled = false
	end

	self.maid:GiveTask(function(): ()
		self.tweensMaid:DoCleaning()
	end)

	self.maid:GiveTask(ClientData:GetPlayerProducerAsync():expect():subscribe(function(state): any
		local playerState: any = state.player

		return playerState and playerState[self.currencyKey]
	end, function(amount: string): ()
		local currentAmount: number = ConvertCurrency.StringToNumber(amount)

		instance.Text = `{self.prefix}{ConvertCurrency.SuffixFormat(currentAmount)}`

		if self.lastAmount then
			self:ShowMoneyChange(currentAmount - self.lastAmount)
		end

		self.lastAmount = currentAmount

		self:PlayMoneyPulseEffect()
	end))

	ClientData:GetPlayerProducerAsync():andThen(function(producer): ()
		local playerState: any = producer:getState().player
		local currentAmount: number = ConvertCurrency.StringToNumber(playerState and playerState[self.currencyKey])

		instance.Text = `{self.prefix}{ConvertCurrency.SuffixFormat(currentAmount)}`

		self.lastAmount = currentAmount

		self:PlayMoneyPulseEffect()
	end)

	return self
end

function MoneyCounter:ShowMoneyChange(difference: number): ()
	if self.moneyChangeEnabled == false then
		return
	end

	if difference == 0 then
		return
	end

	local container: Frame? = self.moneyChangeContainer

	if not container then
		return
	end

	local label: TextLabel = Instance.new("TextLabel")
	label.Name = "MoneyChangeLabel"
	label.AnchorPoint = Vector2.one * 0.5
	label.BackgroundTransparency = 1
	label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	label.LineHeight = 0.5
	label.RichText = true
	label.Size = UDim2.fromScale(0.95, 0.25)
	label.Text = ""
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = container.ZIndex + 1

	local stroke: UIStroke = Instance.new("UIStroke")
	stroke.Name = "UIStroke"
	stroke.Color = Color3.fromRGB(3, 3, 40)
	stroke.Thickness = 2.5
	stroke.Parent = label

	local positiveGradient: UIGradient = Instance.new("UIGradient")
	positiveGradient.Name = "Pos"
	positiveGradient.Color = POSITIVE_GRADIENT
	positiveGradient.Enabled = false
	positiveGradient.Rotation = 90
	positiveGradient.Parent = label

	local negativeGradient: UIGradient = Instance.new("UIGradient")
	negativeGradient.Name = "Neg"
	negativeGradient.Color = NEGATIVE_GRADIENT
	negativeGradient.Enabled = false
	negativeGradient.Rotation = 90
	negativeGradient.Parent = label

	local sign: string = difference > 0 and "+" or "-"
	local formatted: string = ConvertCurrency.SuffixFormat(math.abs(difference))

	label.Text = `{sign}{self.prefix}{formatted}`
	label.LayoutOrder = #container:GetChildren()

	local gradientToEnable: UIGradient? = difference > 0 and positiveGradient or negativeGradient

	if gradientToEnable then
		gradientToEnable.Enabled = true
	end

	label.Parent = container

	task.delay(CHANGE_FADE_DELAY, function(): ()
		if not label.Parent then
			return
		end

		local textTween: Tween = TweenService:Create(label, CHANGE_FADE_TWEEN_INFO, { TextTransparency = 1 })
		local strokeTween: Tween = TweenService:Create(stroke, CHANGE_FADE_TWEEN_INFO, { Transparency = 1 })

		textTween:Play()
		strokeTween:Play()

		strokeTween.Completed:Wait()

		label:Destroy()
	end)
end

function MoneyCounter:PlayMoneyPulseEffect(): ()
	self.tweensMaid:DoCleaning()

	local instance: TextLabel = self.instance
	local base: UDim2 = self.baseSize
	local config = EffectGuiConfig.MoneyPulse

	local expanded: UDim2 = UDim2.new(
		base.X.Scale * config.MaxScale,
		base.X.Offset * config.MaxScale,
		base.Y.Scale * config.MaxScale,
		base.Y.Offset * config.MaxScale
	)

	local expandTween: Tween = TweenService:Create(instance, config.ExpandTweenInfo, { Size = expanded })
	local returnTween: Tween = TweenService:Create(instance, config.ReturnTweenInfo, { Size = base })

	self.tweensMaid:GiveTask(function(): ()
		instance.Size = base
	end)

	self.tweensMaid:GiveTask(expandTween)
	self.tweensMaid:GiveTask(returnTween)

	self.tweensMaid:GiveTask(expandTween.Completed:Connect(function(): ()
		returnTween:Play()
	end))

	expandTween:Play()
end

function MoneyCounter:Destroy(): ()
	self.maid:DoCleaning()
end

return MoneyCounter
