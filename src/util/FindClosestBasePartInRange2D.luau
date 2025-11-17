local Players = game:GetService("Players")

return function(baseParts: { BasePart }, range: number): BasePart?
	local closest: BasePart, distance: number
	local character: Model? = Players.LocalPlayer.Character
	if not character then
		return
	end

	for _index: number, basePart: BasePart in baseParts do
		local characterPivot: CFrame = character:GetPivot()
		local basePartDistance: number = (Vector2.new(characterPivot.X, characterPivot.Z) - Vector2.new(
			basePart.CFrame.X,
			basePart.CFrame.Z
		)).Magnitude

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
