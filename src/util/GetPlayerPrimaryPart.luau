return function(player: Player): BasePart?
	local primaryPart: BasePart? = player.Character and player.Character.PrimaryPart
	if not primaryPart then
		return
	end

	return primaryPart
end
