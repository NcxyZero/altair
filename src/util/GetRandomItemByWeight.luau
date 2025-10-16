return function(itemsPossibleToDrop: { [string]: { Weight: number, [any]: any } }, luckToConsider: number?): string
	local luck: number = luckToConsider or 1

	local lowestWeight: number = -1
	local lowestDropConfigName: string = nil
	local possibleToDrop = {}

	for index: string, value: { Weight: number } in itemsPossibleToDrop do
		if value.Weight < lowestWeight or lowestWeight == -1 then
			lowestWeight = value.Weight
			lowestDropConfigName = index
		end

		local shouldBeDroped: boolean = math.random(1, value.Weight // luck) == 1
		if shouldBeDroped then
			table.insert(possibleToDrop, { configName = index, weight = value.Weight })
		end
	end

	table.sort(possibleToDrop, function(a, b)
		return a.weight > b.weight
	end)

	if #possibleToDrop > 0 then
		return possibleToDrop[1].configName
	else
		return lowestDropConfigName
	end
end
