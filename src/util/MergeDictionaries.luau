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

return function<T1, T2>(dictionaryA: T1 & { [string]: any }, dictionaryB: T2 & { [string]: any }): T1 & T2
	local mergedDictionary = deepClone(dictionaryA)

	for key: string, value: any in pairs(deepClone(dictionaryB)) do
		mergedDictionary[key] = value
	end

	return mergedDictionary
end
