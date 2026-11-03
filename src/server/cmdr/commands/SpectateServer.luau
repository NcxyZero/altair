local ServerScriptService = game:GetService("ServerScriptService")

local PlayerObservationController = require(ServerScriptService.server.modules.PlayerObservationController)

return function(context: any, player: Player, keepHUD: boolean?): string
	local _success: boolean, message: string =
		PlayerObservationController:SetSpectate(context.Executor, player, keepHUD)

	return message
end
