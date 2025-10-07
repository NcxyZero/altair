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
	Destroy: (self: Default) -> (),
}

local ClientTagTemplate: Default = {} :: Default
ClientTagTemplate.__index = ClientTagTemplate
ClientTagTemplate.type = "tag"
ClientTagTemplate.tag = "Template"

function ClientTagTemplate.new(instance: Instance, path: InitializerTypes.ClientPath): Default
	local self = setmetatable({}, ClientTagTemplate)
	self.instance = instance
	self.path = path
	self.maid = Maid.new()
	Logger.print("ClientTagTemplate initalized instance: " .. instance.Name)

	return self
end

function ClientTagTemplate:Destroy(): ()
	self.maid:DoCleaning()
end

return ClientTagTemplate
