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

local ServerTagTemplate: Default = {} :: Default
ServerTagTemplate.type = "tag"
ServerTagTemplate.tag = "Template"

function ServerTagTemplate.new(instance: Instance)
	local self = setmetatable(ServerTagTemplate, {})
	self.instance = instance
	self.maid = Maid.new()
	Logger.print("ServerTagTemplate initalized instance: " .. instance.Name)

	return self
end

function ServerTagTemplate:Destroy()
	self.maid:DoCleaning()
end

return ServerTagTemplate
