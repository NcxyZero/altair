local function lerpAngle(a: number, b: number, t: number): number
	local diff = b - a
	diff = (diff + math.pi) % (2 * math.pi) - math.pi

	return a + diff * t
end

return lerpAngle
