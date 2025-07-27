local Players = game:GetService("Players")

return function(baseParts: { BasePart }, range: number): BasePart?
	local closest: BasePart, distance: number

	for _index: number, basePart: BasePart in baseParts do
		local basePartDistance: number = Players.LocalPlayer:DistanceFromCharacter(basePart.Position)

		if basePartDistance > range then
			continue
		end

		if not closest or basePartDistance < distance then
			closest = basePart
			distance = basePartDistance
		end
	end

	return closest
end
