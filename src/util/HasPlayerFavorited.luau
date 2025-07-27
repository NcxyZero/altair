local HttpService = game:GetService("HttpService")

local favourtieChecker = {}

function favourtieChecker:Check(Player: Player): boolean?
	local gameId: { number } = { game.GameId }
	local hasFavorited: boolean = false
	local data: { Data: { Items: { Item: { UniverseId: number } } } }

	local success: boolean = pcall(function(): ()
		local get: string = HttpService:GetAsync(
			"https://www.roproxy.com/users/favorites/list-json?assetTypeId=9&itemsPerPage=100&pageNumber=1&userId="
				.. Player.UserId
		)
		data = HttpService:JSONDecode(get)
	end)

	if not success then
		warn("Failed to fetch favorites for player: " .. Player.Name)
		return
	end

	local favorites: { { Item: { UniverseId: number } } } = data.Data.Items
	for _index: number, Place: { Item: { UniverseId: number } } in pairs(favorites) do
		if table.find(gameId, Place.Item.UniverseId) then
			hasFavorited = true
			break
		end
	end

	return hasFavorited
end

return favourtieChecker
