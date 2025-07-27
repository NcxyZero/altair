return function(
	start: number,
	velocity: number,
	goal: number,
	stiffness: number,
	dampening: number,
	precision: number,
	alpha: number
): (number, number)
	alpha = math.min(alpha, 0.05) --to avoid having frametimes over this value, springs usually tend to go insane otherwise.

	local FSpring: number = -stiffness * (start - goal)
	local FDamper: number = -dampening * velocity
	local A: number = FSpring + FDamper

	local NewVelocity: number = velocity + A * alpha
	local NewPosition: number = start + NewVelocity * alpha

	if math.abs(NewVelocity) < precision and math.abs(start - NewPosition) < precision then
		return goal, 0
	end

	if
		NewPosition >= math.huge
		or NewVelocity >= math.huge
		or NewPosition ~= NewPosition
		or NewVelocity ~= NewVelocity
	then
		return start, velocity
	end

	return NewPosition, NewVelocity
end
