local function isPointInsideBounds(point: Vector3, origin: CFrame, boundsSize: Vector3, padding: number?): boolean
	local offset = origin:PointToObjectSpace(point)
	local size = boundsSize + Vector3.new(padding, padding, padding)

	return math.abs(offset.X) <= size.X / 2 and math.abs(offset.Y) <= size.Y / 2 and math.abs(offset.Z) <= size.Z / 2
end

return isPointInsideBounds
