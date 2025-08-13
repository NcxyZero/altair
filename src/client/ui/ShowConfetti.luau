local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Confetti = require(ReplicatedStorage.util.Confetti)
local Maid = require(ReplicatedStorage.package.Maid)
local OpenGui = require(ReplicatedStorage.util.OpenGui)

type Button = TextButton & {
	Frame: Frame,
	Amount: TextLabel,
}

export type Default = {
	type: string,
	tag: string,
	path: { any },
	instance: Button,
	maid: Maid.Maid,
	__index: Default,
	new: (instance: Button) -> Default,
	Destroy: (self: Default) -> (),
}

local TemplateUI: Default = {} :: Default
TemplateUI.__index = TemplateUI
TemplateUI.type = "local_tag"
TemplateUI.tag = "Confetti"

function TemplateUI.new(instance: Button): Default
	local self = setmetatable(TemplateUI, {})
	self.instance = instance
	self.maid = Maid.new()

	print(instance)

	self.maid:GiveTask(instance.Activated:Connect(function(): ()
		self.maid = Maid.new()

		Confetti:Show(200)
	end))

	return self
end

function TemplateUI:Destroy(): ()
	self.maid:DoCleaning()
end

return TemplateUI
