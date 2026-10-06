local function deepClone<T>(original: T & { [any]: any }): T
	local copy: { [any]: any } = {}

	for key: any, value: any in original :: { [any]: any } do
		if type(value) == "table" then
			value = deepClone(value)
		end
		copy[key] = value
	end

	return (copy :: any) :: T
end

return deepClone
