local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Logger)
local Maid = require(ReplicatedStorage.package.Maid)

export type Default = {
	type: string,
	tag: string,
	path: InitializerTypes.ClientPath,
	instance: Instance,
	maid: Maid.Maid,
	__index: Default,
	new: (instance: Instance, path: InitializerTypes.ClientPath) -> Default,
	Destroy: () -> (),
}

local ClientLocalTagTemplate: Default = {} :: Default
ClientLocalTagTemplate.__index = ClientLocalTagTemplate
ClientLocalTagTemplate.type = "local_tag"
ClientLocalTagTemplate.tag = "Local_Template"

function ClientLocalTagTemplate.new(instance: Instance, path: InitializerTypes.ClientPath): Default
	local self = setmetatable(ClientLocalTagTemplate, {})
	self.path = path
	self.instance = instance
	self.maid = Maid.new()
	Logger.print("ClientLocalTagTemplate initalized instance: " .. instance.Name)

	return self
end

function ClientLocalTagTemplate:Destroy(): ()
	self.maid:DoCleaning()
end

return ClientLocalTagTemplate
