local function isPointInsidePart(point: Vector3, part: BasePart, padding: number?): boolean
	local offset = part.CFrame:PointToObjectSpace(point)
	local size = part.Size + Vector3.new(padding, padding, padding)

	return math.abs(offset.X) <= size.X / 2 and math.abs(offset.Y) <= size.Y / 2 and math.abs(offset.Z) <= size.Z / 2
end

return isPointInsidePart
