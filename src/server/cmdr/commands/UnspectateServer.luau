local ServerScriptService = game:GetService("ServerScriptService")

local PlayerObservationController = require(ServerScriptService.server.modules.PlayerObservationController)

return function(context: any): string
	local _success: boolean, message: string = PlayerObservationController:SetSpectate(context.Executor, nil)

	return message
end
