local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bridgenet2 = require(ReplicatedStorage.package.Bridgenet2)
local GetBridge = require(ReplicatedStorage.util.GetBridge)

local bridge = GetBridge("Notification")

return function(_context, players: { Player }, message: string, seconds: number?): string
	bridge:Fire(Bridgenet2.Players(players), { text = message, seconds = seconds or 5 })

	return `Notification sent for {seconds or 5} seconds.`
end
