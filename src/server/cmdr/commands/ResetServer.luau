local ServerScriptService = game:GetService("ServerScriptService")

local ServerData = require(ServerScriptService.server.modules.ServerData)

return function(_context, players: { Player }): string
	local playersToLog: { string } = {}

	for _index: number, player: Player in players do
		local producer = ServerData:GetPlayerProducerAsync(player):expect()
		producer.secureResetData()
		player:Kick("Data reset")
		table.insert(playersToLog, player.Name)
	end

	return `Kicked and cleared all data for {table.concat(playersToLog, ", ")}`
end
