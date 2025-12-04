local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ClientData = require(ReplicatedStorage.client.modules.ClientData)
local ConvertCurrency = require(ReplicatedStorage.util.ConvertCurrency)
local EffectGuiConfig = require(ReplicatedStorage.shared.config.EffectGuiConfig)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)

export type Default = {
	type: string,
	tag: string,
	path: InitializerTypes.ClientPath,
	instance: TextLabel,
	baseSize: UDim2,
	maid: Maid.Maid,
	tweensMaid: Maid.Maid,
	closeButtonsMaid: Maid.Maid?,
	closeButtons: { GuiObject }?,
	__index: Default,
	new: (instance: TextLabel, path: InitializerTypes.ClientPath) -> Default,
	PlayMoneyPulseEffect: (self: Default) -> (),
	Destroy: (self: Default) -> (),
}

local MoneyCounter: Default = {} :: Default
MoneyCounter.__index = MoneyCounter
MoneyCounter.type = "local_tag"
MoneyCounter.tag = "MoneyCounter"

function MoneyCounter.new(instance: TextLabel, path: InitializerTypes.ClientPath): Default
	local self = setmetatable({}, MoneyCounter)
	self.instance = instance
	self.path = path

	self.maid = Maid.new()
	self.tweensMaid = Maid.new()

	self.baseSize = instance.Size

	self.maid:GiveTask(function(): ()
		self.tweensMaid:DoCleaning()
	end)

	self.maid:GiveTask(ClientData:GetPlayerProducerAsync():expect():subscribe(function(state): string
		return state.player.money
	end, function(money: string): ()
		instance.Text = `${ConvertCurrency.SuffixFormat(ConvertCurrency.StringToNumber(money))}`

		self:PlayMoneyPulseEffect()
	end))

	ClientData:GetPlayerProducerAsync():andThen(function(producer): ()
		instance.Text =
			`${ConvertCurrency.SuffixFormat(ConvertCurrency.StringToNumber(producer:getState().player.money))}`

		self:PlayMoneyPulseEffect()
	end)

	return self
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
