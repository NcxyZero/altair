return function(rewards: { { chance: number, [any]: any } })
	local max = 0
	local items = {}

	for index, data in rewards do
		max += data.chance
		items[max] = index
	end

	local random = math.random(max)
	local reward

	for chance, index in items do
		if chance >= random then
			reward = rewards[index]
			break
		end
	end

	return reward
end
