local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Logger)

export type TagManager = {
	path: InitializerTypes.ServerPath | InitializerTypes.ClientPath,
	GetTagTable: (self: TagManager, instance: Instance) -> { [string]: unknown }?,
	GetTagClass: (self: TagManager, instance: Instance, tagName: string) -> unknown?,
}

local TagManager: TagManager = {
	type = "controller",
	index = 1,
} :: any

function TagManager:GetTagTable(instance: Instance): { [string]: unknown }?
	if not self.path then
		Logger.error(`No self.path found for TagManager! This should never happen.`)
		return
	end

	local tagPath: { [Instance]: { [string]: unknown } }? = self.path.tag
	if not tagPath then
		Logger.warn(`GetTagTable: No tag path found for instance`)
		return
	end

	return tagPath[instance]
end

function TagManager:GetTagClass(instance: Instance, tagName: string): unknown?
	local classes: { [string]: unknown }? = self:GetTagTable(instance)
	if not classes then
		Logger.warn(`GetTagClass: No classes found for instance with tagName "{tagName}"`)
		return
	end

	return classes[tagName]
end

return TagManager
