return function(data: { [any]: any }): { any }
	local constructedArray: { any } = {}

	for key: any in data do
		table.insert(constructedArray, key)
	end

	return constructedArray
end
