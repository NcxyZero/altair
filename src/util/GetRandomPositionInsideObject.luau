local random: Random = Random.new()

local function pickRandomPositionInsideObject(object: BasePart): Vector3
	local size: Vector3 = object.Size

	return object.CFrame:ToWorldSpace(
		CFrame.new(
			random:NextNumber(-size.X / 2, size.X / 2),
			random:NextNumber(-size.Y / 2, size.Y / 2),
			random:NextNumber(-size.Z / 2, size.Z / 2)
		)
	).Position
end

return pickRandomPositionInsideObject
