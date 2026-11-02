return function(hex: string): number
	local byte: number = hex:byte()
	if byte >= ("0"):byte() and byte <= ("9"):byte() then
		return byte - ("0"):byte()
	end

	local lower: number = hex:lower():byte()
	if lower >= ("a"):byte() and lower <= ("f"):byte() then
		return 10 + lower - ("a"):byte()
	end

	return 0
end
