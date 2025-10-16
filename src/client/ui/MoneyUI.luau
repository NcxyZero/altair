local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConvertCurrency = require(ReplicatedStorage.util.ConvertCurrency)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)

export type Default = {
	type: string,
	tag: string,
	path: InitializerTypes.ClientPath,
	instance: TextLabel,
	maid: Maid.Maid,
	__index: Default,
	new: (instance: TextLabel, path: InitializerTypes.ClientPath) -> Default,
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
	self.maid:GiveTask(
		self.path.controller.ClientData:getPlayerProducerAsync():expect():subscribe(function(state): string
			return state.player.money
		end, function(money: string): ()
			instance.Text = `${ConvertCurrency.SuffixFormat(ConvertCurrency.StringToNumber(money))}`
		end)
	)

	self.path.controller.ClientData:getPlayerProducerAsync():andThen(function(producer): ()
		instance.Text =
			`${ConvertCurrency.SuffixFormat(ConvertCurrency.StringToNumber(producer.getState().player.money))}`
	end)

	return self
end

function MoneyCounter:Destroy(): ()
	self.maid:DoCleaning()
end

return MoneyCounter
