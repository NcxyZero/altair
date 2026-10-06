local ServerScriptService = game:GetService("ServerScriptService")

local ServerData = require(ServerScriptService.server.modules.ServerData)

return function(_context: any, players: { Player }): string
	local resetPlayers: { string } = {}
	local failedPlayers: { string } = {}

	for _index: number, player: Player in players do
		if ServerData:ResetPlayerData(player) then
			table.insert(resetPlayers, player.Name)
			player:Kick("Data reset")
		else
			table.insert(failedPlayers, player.Name)
		end
	end

	local result: string = `Reset data and kicked: {table.concat(resetPlayers, ", ")}`
	if #failedPlayers > 0 then
		result ..= `. Failed to reset: {table.concat(failedPlayers, ", ")}`
	end

	return result
end
