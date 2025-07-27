local function lerpNumber(current: number, target: number, alpha: number): number
	return current + (target - current) * alpha
end

return lerpNumber
