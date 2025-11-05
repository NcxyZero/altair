local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)

export type Default = {
	type: string,
	tag: string,
	path: InitializerTypes.ClientPath,
	instance: Instance & any,
	maid: Maid.Maid,
	closeButtonsMaid: Maid.Maid?,
	closeButtons: { GuiObject }?,
	__index: Default,
	new: (instance: Instance & any) -> Default,
	Destroy: (self: Default) -> (),
}

local TemplateUI: Default = {} :: Default
TemplateUI.__index = TemplateUI
TemplateUI.type = "local_tag"
TemplateUI.tag = script.Name
--TemplateUI.closeButtons = {}

function TemplateUI.new(instance: Instance & any): Default
	local self = setmetatable({}, TemplateUI)
	self.instance = instance
	--table.insert(self.closeButtons, instance.CloseButton)

	return self
end

function TemplateUI:Destroy(): ()
	self.maid:DoCleaning()

	if self.closeButtonsMaid then
		self.closeButtonsMaid:DoCleaning()
	end
end

return TemplateUI
