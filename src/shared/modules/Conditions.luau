local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local ProfileTypes = require(ReplicatedStorage.shared.reflex.ProfileTypes)
local WithoutPlayer = require(ReplicatedStorage.util.WithoutPlayer)

export type ConditionsServer = {
	path: InitializerTypes.ServerPath,
	CheckCondition: (self: Conditions, player: Player, conditionType: string, value: any) -> boolean,
}

export type ConditionsClient = {
	path: InitializerTypes.ClientPath,
	CheckCondition: (self: Conditions, conditionType: string, value: any) -> boolean,
}

export type Conditions = ConditionsServer & ConditionsClient

type ConditionsMethods = {
	CheckCondition: (self: Conditions, player: Player?, conditionType: string, value: any) -> boolean,
	type: string,
}

local ConditionsMethods: ConditionsMethods = {
	type = "other",
} :: ConditionsMethods

local conditions: { [string]: (ProfileTypes.PlayerProducer, any, Player?) -> boolean } = {
	offers = function(producer, name: string): boolean
		return producer:getState().monetization.offers[name]
	end,
	passes = function(producer, name: string, _player: Player?): boolean
		local passes: any = producer:getState().monetization.passes

		return passes and passes[name] == true or false
	end,
	rebirth = function(producer, required: number): boolean
		return producer:getState().player.rebirth >= required
	end,
}

function ConditionsMethods.CheckCondition(self: Conditions, player: Player?, conditionType: string, value: any): boolean
	local producer: ProfileTypes.PlayerProducer
	if player then
		producer = self.path.controller.ServerData:GetPlayerProducerAsync(player):expect()
	else
		producer = self.path.controller.ClientData:GetPlayerProducerAsync():expect()
	end

	return conditions[conditionType](producer, value, player)
end

local ConditionsServer: ConditionsServer = setmetatable({}, { __index = ConditionsMethods }) :: any
local ConditionsClient: ConditionsClient = setmetatable({
	CheckCondition = WithoutPlayer(ConditionsMethods.CheckCondition),
}, { __index = ConditionsMethods }) :: any

return (RunService:IsServer() and ConditionsServer or ConditionsClient) :: Conditions
