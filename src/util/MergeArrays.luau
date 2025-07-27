return function<T>(...: T): { T }
	local arrays: { T } = { ... }
	local finalArray: { T } = {}

	for _index: number, array: T in arrays do
		for _index: number, value: any in array :: any do
			table.insert(finalArray, value)
		end
	end

	return finalArray :: { T }
end
