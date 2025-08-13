local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require(ReplicatedStorage.package.Maid)
local OpenGui = require(ReplicatedStorage.util.OpenGui)

type Shop = ScreenGui & {
	Frame: Frame,
	Toggle: TextButton,
}

export type Default = {
	type: string,
	tag: string,
	path: { any },
	instance: Shop,
	maid: Maid.Maid,
	__index: Default,
	new: (instance: Shop) -> Default,
	Destroy: (self: Default) -> (),
}

local TemplateUI: Default = {} :: Default
TemplateUI.__index = TemplateUI
TemplateUI.type = "local_tag"
TemplateUI.tag = "TemplateUI"

function TemplateUI.new(instance: Shop): Default
	local self = setmetatable(TemplateUI, {})
	self.instance = instance

	self.maid = Maid.new()

	self.maid:GiveTask(instance.Toggle.Activated:Connect(function(): ()
		if OpenGui.current.id == instance then
			OpenGui:Handle()
			return
		end

		OpenGui:Handle(instance, function(): ()
			instance.Frame.Visible = true
		end, function(): ()
			instance.Frame.Visible = false
		end)
	end))

	return self
end

function TemplateUI:Destroy(): ()
	self.maid:DoCleaning()
end

return TemplateUI
