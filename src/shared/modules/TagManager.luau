local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Logger)

export type TagManager = {
	path: InitializerTypes.ServerPath | InitializerTypes.ClientPath,
	GetTagTable: (self: TagManager, instance: Instance) -> { [string]: unknown }?,
	GetTagClass: (self: TagManager, instance: Instance, tagName: string) -> unknown?,
	GetLocalTagCollection: (self: TagManager) -> { [Instance]: unknown }?,
	FindLocalTagClass: (self: TagManager, tagName: string) -> unknown?,
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

function TagManager:GetLocalTagCollection(): { [Instance]: unknown }?
	if not self.path then
		Logger.errorStack("No self.path found for TagManager! This should never happen.")

		return
	end

	return self.path.local_tag
end

function TagManager:FindLocalTagClass(tagName: string): unknown?
	local collection: { [Instance]: unknown }? = self:GetLocalTagCollection()
	if not collection then
		return
	end

	local current: Instance? = next(collection)
	while current do
		local class: any = collection[current]
		if class and class.tag == tagName then
			return class
		end

		current = next(collection, current)
	end

	return
end

return TagManager
