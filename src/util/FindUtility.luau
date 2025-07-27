local function findValue<K, V>(input: { [K]: V }, callback: (V, K) -> boolean): V?
	for key: K, value: V in input do
		local match: boolean = callback(value, key)

		if match then
			return value
		end
	end

	return
end

local function findKey<K, V>(input: { [K]: V }, callback: (V, K) -> boolean): K?
	for key: K, value: V in input do
		local match: boolean = callback(value, key)

		if match then
			return key
		end
	end

	return
end

return {
	findValue = findValue,
	findKey = findKey,
}
