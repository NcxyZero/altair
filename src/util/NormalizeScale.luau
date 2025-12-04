local NormalizeScale = {}

function NormalizeScale.ComputeRange(minScale: number, maxScale: number): number
	minScale = tonumber(minScale) or 0
	maxScale = tonumber(maxScale) or 0

	return math.max(1e-6, maxScale - minScale)
end

function NormalizeScale.ClampScale(value: number, minScale: number, maxScale: number): number
	return math.clamp(tonumber(value) or 0, tonumber(minScale) or 0, tonumber(maxScale) or tonumber(minScale) or 1)
end

function NormalizeScale.PercentFromScale(value: number, minScale: number, maxScale: number): number
	local range: number = NormalizeScale.ComputeRange(minScale, maxScale)

	return math.clamp(((tonumber(value) or 0) - (tonumber(minScale) or 0)) / range, 0, 1)
end

return NormalizeScale
