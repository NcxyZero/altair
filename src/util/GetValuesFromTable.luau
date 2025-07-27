return function(dictionary: { [string]: any }): { any }
	local constructedArray: { any } = {}

	for _key: string, value: any in dictionary do
		table.insert(constructedArray, value)
	end

	return constructedArray
end
