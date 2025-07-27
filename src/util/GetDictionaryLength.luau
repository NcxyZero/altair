return function(dictionary: { [any]: any }): number
	local count: number = 0
	for _ in dictionary or {} :: any do
		count += 1
	end

	return count
end
