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

local ClientTagTemplate: Default = {} :: Default
ClientTagTemplate.type = "tag"
ClientTagTemplate.tag = "Template"

function ClientTagTemplate.new(instance: Instance)
	local self = setmetatable(ClientTagTemplate, {})
	self.instance = instance
	self.maid = Maid.new()
	Logger.print("ClientTagTemplate initalized instance: " .. instance.Name)

	return self
end

function ClientTagTemplate:Destroy()
	self.maid:DoCleaning()
end

return ClientTagTemplate
