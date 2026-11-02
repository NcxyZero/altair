return function(seconds: number): string
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	local secs = math.floor(seconds % 60)

	local result = ""

	if hours > 0 then
		result ..= hours .. "h "
	end

	if minutes > 0 then
		result ..= minutes .. "min "
	end

	if secs > 0 or result == "" then
		result ..= secs .. "s"
	end

	return result
end
