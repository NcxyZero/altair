local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local APIDictionaries = require(ReplicatedStorage.shared.types.APIDictionaries)
local Logger = require(ReplicatedStorage.util.Logger)

local favouriteCache = {}
local playerFavCheckCooldowns = {}

local playerFavCheckCooldown: number = 3

return function(player: Player, universeId: number?): boolean
	if table.find(favouriteCache, player.UserId) then
		return true
	end

	local targetUniverseId: number = universeId or game.GameId

	if
		playerFavCheckCooldowns[player]
		and workspace:GetServerTimeNow() - playerFavCheckCooldowns[player] < playerFavCheckCooldown
	then
		return false
	end

	playerFavCheckCooldowns[player] = workspace:GetServerTimeNow()

	local requestData: APIDictionaries.HttpRequestOptions = {
		Url = `https://games.roproxy.com/v2/users/{player.UserId}/favorite/games?cursor=&limit=100&sortOrder=Desc`,
		Method = "GET",
		Headers = {},
	}

	local success: boolean, response: APIDictionaries.HttpResponseData = xpcall(
		function(): APIDictionaries.HttpResponseData
			return HttpService:RequestAsync(requestData)
		end,
		Logger.warn
	)

	if success and response.Body then
		local success2: boolean, data = xpcall(HttpService.JSONDecode, Logger.warn, HttpService, response.Body)
		if not success2 then
			return false
		end

		local hasFavorited: boolean = false

		xpcall(function(): ()
			local favorites = data.data
			for _index: number, place: any in favorites do
				if place.id == targetUniverseId then
					hasFavorited = true

					break
				end
			end
		end, Logger.warn)

		if hasFavorited then
			table.insert(favouriteCache, player.UserId)
		end

		return hasFavorited
	end

	return false
end
