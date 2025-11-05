local function removeCharacterFromSeat(humanoid: Humanoid): ()
	local seatPart: Seat | VehicleSeat = humanoid.SeatPart :: any
	if not seatPart then
		return
	end

	local seatWeld: WeldConstraint? = seatPart:FindFirstChild("SeatWeld") :: any
	if seatWeld then
		seatWeld:Destroy()
	end

	humanoid.Sit = false

	task.wait()
end

return function(character: Model, target: CFrame, keepSitting: true?): boolean
	local humanoid: Humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return false
	end

	if not keepSitting then
		removeCharacterFromSeat(humanoid)
	end

	character:PivotTo(target)

	return true
end
