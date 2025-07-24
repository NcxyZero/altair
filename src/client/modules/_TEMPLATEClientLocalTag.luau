local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.util.Logger)
local Maid = require(ReplicatedStorage.package.Maid)
export type Default = {
	type: string,
	tag: string,
	path: { any },
	instance: Instance,
	maid: Maid.Maid,
	__index: Default,
	new: (instance: Instance) -> Default,
	Destroy: () -> (),
}

local ClientLocalTagTemplate: Default = {} :: Default
ClientLocalTagTemplate.type = "local_tag"
ClientLocalTagTemplate.tag = "Local_Template"

function ClientLocalTagTemplate.new(instance: Instance)
	local self = setmetatable(ClientLocalTagTemplate, {})
	self.instance = instance
	self.maid = Maid.new()
	Logger.print("ClientLocalTagTemplate initalized instance: " .. instance.Name)

	return self
end

function ClientLocalTagTemplate:Destroy()
	self.maid:DoCleaning()
end

return ClientLocalTagTemplate
