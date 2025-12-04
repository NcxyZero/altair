local Players = game:GetService("Players")

return function(waitForAll: true?): { Model }
	local collection: { Model } = {}

	for _index: number, player: Player in Players:GetPlayers() do
		local character: Model? = player.Character or waitForAll and player.CharacterAdded:Wait()
		if character then
			table.insert(collection, character)
		end
	end

	return collection
end
