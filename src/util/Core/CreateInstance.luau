export type InstanceCreator =
	((className: string, properties: { [string]: any }?) -> Instance & any)
	& ((className: string, parent: Instance, properties: { [string]: any }?) -> Instance & any)
	& ((className: string, name: string, properties: { [string]: any }?) -> Instance & any)
	& ((className: string, parent: Instance, name: string, properties: { [string]: any }?) -> Instance & any)

local func: InstanceCreator = function(className: string, a, b, c): Instance & any
	local instance: Instance = Instance.new(className)
	local name: string? = type(a) == "string" and a or type(b) == "string" and b or nil
	local parent: Instance? = typeof(a) == "Instance" and a or nil
	local properties: { [string]: any }? = type(a) == "table" and a
		or type(b) == "table" and b
		or type(c) == "table" and c
		or nil

	if name then
		instance.Name = name
	end

	if parent then
		instance.Parent = parent
	end

	if properties then
		for propertyName: string, propertyValue: any in properties do
			instance[propertyName] = propertyValue
		end
	end

	return instance
end

return func
