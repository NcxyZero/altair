local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ConvertCurrency = require(ReplicatedStorage.util.ConvertCurrency)
local ServerData = require(ServerScriptService.server.modules.ServerData)

return function(_context, players: { Player }, amount: number): string
	local playersToLog: { string } = {}
	local playersBalance: { string } = {}

	for _index: number, player: Player in players do
		local profile = ServerData:WaitForPlayerProfile(player):expect()
		profile.producer.secureSpendMoney(amount)

		table.insert(playersToLog, player.Name)
		table.insert(
			playersBalance,
			`{player.Name}'s balance: ${ConvertCurrency.SuffixFormat(
				ConvertCurrency.StringToNumber(profile.producer.getState().player.money)
			)}`
		)
	end

	return `${amount} taken from {table.concat(playersToLog, ", ")}{#playersBalance > 0 and "\n" or ""}{table.concat(
		playersBalance,
		"\n"
	)}`
end
