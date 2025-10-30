local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local isServer: boolean = RunService:IsServer()

local CacheManager = isServer and require(ServerScriptService.server.modules.CacheManager) or nil

export type Conditions = {
	CheckCondition: (
		self: Conditions,
		player: Player,
		conditionType: string,
		value: any
	) -> boolean & (self: Conditions, conditionType: string, value: any) -> boolean,
}

local Conditions = {
	passes = function(producer, name: string, player: Player?): boolean
		return producer:getState().monetization.passes[name]
			or (isServer and player and CacheManager:CheckCondition(player, "monetization", "passes", name))
	end,
	rebirth = function(producer, required: number): boolean
		return producer:getState().player.rebirth >= required
	end,
}

local ConditionsServer = {}
local ConditionsClient = {}

function ConditionsServer:CheckCondition(player: Player, conditionType: string, value: any): boolean
	local producer = self.path.controller.ServerData:WaitForPlayerProfile(player):expect().producer

	return Conditions[conditionType](producer, value, player)
end

function ConditionsClient:CheckCondition(conditionType: string, value: any): boolean
	local producer = self.path.controller.ClientData:getPlayerProducerAsync():expect()

	return Conditions[conditionType](producer, value)
end

return (isServer and ConditionsServer or ConditionsClient) :: Conditions
