local HttpService = game:GetService("HttpService")

local favouriteCache = {}
local playerFavCheckCooldowns = {}

local playerFavCheckCooldown: number = 3

return function(player: Player): boolean
	if table.find(favouriteCache, player.UserId) then
		return true
	end

	if
		playerFavCheckCooldowns[player]
		and workspace:GetServerTimeNow() - playerFavCheckCooldowns[player] < playerFavCheckCooldown
	then
		return false
	end

	playerFavCheckCooldowns[player] = workspace:GetServerTimeNow()

	local requestData = {
		Url = `https://games.roproxy.com/v2/users/{player.UserId}/favorite/games?cursor=&limit=100&sortOrder=Desc`,
		Method = "GET",
		Headers = {},
	}

	local success: boolean, response = pcall(function()
		return HttpService:RequestAsync(requestData)
	end)

	if success and response.Body then
		local success2: boolean, data = pcall(HttpService.JSONDecode, HttpService, response.Body)
		if not success2 then
			return false
		end

		local hasFavorited: boolean = false
		pcall(function(): ()
			local favorites = data.data
			for _index: number, place in pairs(favorites) do
				if place.id == game.GameId then
					hasFavorited = true

					break
				end
			end
		end)

		if hasFavorited then
			table.insert(favouriteCache, player.UserId)
		end

		return hasFavorited
	end

	return false
end
