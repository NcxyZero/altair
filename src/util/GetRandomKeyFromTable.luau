return function<T>(dictionary: { [T]: any }): T
	local keys: { T } = {}

	for key: T in pairs(dictionary) do
		table.insert(keys, key)
	end

	if #keys == 1 then
		local onlyKey = keys[1]

		return dictionary[onlyKey]
	end

	local position: number = Random.new():NextInteger(1, #keys)
	local key: T = keys[position]

	return key
end
