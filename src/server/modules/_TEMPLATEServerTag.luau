local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Logger)
local Maid = require(ReplicatedStorage.package.Maid)

export type Default = {
	type: string,
	tag: string,
	path: InitializerTypes.ServerPath,
	instance: Instance,
	maid: Maid.Maid,
	__index: Default,
	new: (instance: Instance, path: InitializerTypes.ServerPath) -> Default,
	Destroy: (self: Default) -> (),
}

local ServerTagTemplate: Default = {} :: Default
ServerTagTemplate.__index = ServerTagTemplate
ServerTagTemplate.type = "tag"
ServerTagTemplate.tag = script.Name

function ServerTagTemplate.new(instance: Instance, path: InitializerTypes.ServerPath): Default
	local self = setmetatable({}, ServerTagTemplate)
	self.path = path
	self.instance = instance
	self.maid = Maid.new()
	Logger.print("ServerTagTemplate initalized instance: " .. instance.Name)

	return self
end

function ServerTagTemplate:Destroy(): ()
	self.maid:DoCleaning()
end

return ServerTagTemplate
