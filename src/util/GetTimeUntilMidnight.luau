return function(): number
	local currentTimeUTC: number = os.time(os.date("!*t"))
	local currentUTCDate = os.date("!*t", currentTimeUTC)

	currentUTCDate.hour = 0
	currentUTCDate.min = 0
	currentUTCDate.sec = 0

	local nextMidnightUTC: number = os.time(currentUTCDate)

	if nextMidnightUTC <= currentTimeUTC then
		nextMidnightUTC = nextMidnightUTC + 24 * 60 * 60
	end

	return nextMidnightUTC - currentTimeUTC
end
