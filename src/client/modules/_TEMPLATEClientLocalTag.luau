local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Logger)
local Maid = require(ReplicatedStorage.package.Maid)

export type Default = {
	type: string,
	local_tag: string,
	path: InitializerTypes.ClientPath,
	instance: Instance,
	maid: Maid.Maid,
	__index: Default,
	new: (instance: Instance, path: InitializerTypes.ClientPath) -> Default,
	Destroy: (self: Default) -> (),
}

local ClientLocalTagTemplate: Default = {} :: Default
ClientLocalTagTemplate.__index = ClientLocalTagTemplate
ClientLocalTagTemplate.type = "tag"
ClientLocalTagTemplate.local_tag = script.Name

function ClientLocalTagTemplate.new(instance: Instance, path: InitializerTypes.ClientPath): Default
	local self = setmetatable({}, ClientLocalTagTemplate)
	self.instance = instance
	self.path = path
	self.maid = Maid.new()
	Logger.print("ClientLocalTagTemplate initalized instance: " .. instance.Name)

	return self
end

function ClientLocalTagTemplate:Destroy(): ()
	self.maid:DoCleaning()
end

return ClientLocalTagTemplate
