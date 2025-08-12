return function(number)
	local str = tostring(number)
	local sign = ""
	local integerPart = str
	local decimalPart = ""

	-- Sprawdź znak
	if str:sub(1, 1) == "-" then
		sign = "-"
		str = str:sub(2)
		integerPart = str
	end

	-- Sprawdź część dziesiętną
	local dotPos = str:find("%.")
	if dotPos then
		integerPart = str:sub(1, dotPos - 1)
		decimalPart = str:sub(dotPos)
	end

	-- Formatuj część całkowitą
	local formatted = ""
	local len = #integerPart

	for i = 1, len do
		formatted ..= integerPart:sub(i, i)
		if (len - i) % 3 == 0 and i < len then
			formatted ..= ","
		end
	end

	return sign .. formatted .. decimalPart
end
