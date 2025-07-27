function mapNumberSquarely(
	n: number,
	start: number,
	stop: number,
	newStart: number,
	newStop: number,
	withinBounds: number,
	factorial: number
): number
	local value: number = ((n - start) / (stop - start) ^ (factorial or 1)) * (newStop - newStart) + newStart

	if not withinBounds then
		return value
	end

	if newStart < newStop then
		return math.max(math.min(value, newStop), newStart)
	else
		return math.max(math.min(value, newStart), newStop)
	end
end

return mapNumberSquarely
