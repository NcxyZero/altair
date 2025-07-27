local function deepClone<T>(original: T & { [string]: any }): T
	local copy: { [string]: any } = {}

	for key: string, value: any in pairs(original) do
		if type(value) == "table" then
			value = deepClone(value)
		end
		copy[key] = value
	end

	return (copy :: any) :: T
end

return deepClone
