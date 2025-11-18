local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CacheManager = require(ReplicatedStorage.shared.modules.CacheManager)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local MonetizationConfig = require(ReplicatedStorage.shared.config.MonetizationConfig)

local isServer: boolean = RunService:IsServer()

export type ConditionsServer = {
	path: InitializerTypes.ServerPath,
	CheckCondition: (self: Conditions, player: Player, conditionType: string, value: any) -> boolean,
}

export type ConditionsClient = {
	path: InitializerTypes.ClientPath,
	CheckCondition: (self: Conditions, conditionType: string, value: any) -> boolean,
}

export type Conditions = ConditionsServer & ConditionsClient

local Conditions = {
	offers = function(producer, name: string): boolean
		return producer:getState().monetization.offers[name]
	end,
	passes = function(producer, name: string, player: Player?): boolean
		local hasPass: boolean = producer:getState().monetization.passes[name]
		if hasPass then
			return true
		end

		if not (isServer and player) then
			return false
		end

		local key: string = "passes:" .. name
		local value: any = CacheManager:GetOrCompute(player, key, function(): boolean
			local id: number? = MonetizationConfig.passes[name]
			if not id then
				return false
			end

			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
		end, nil, "monetization")

		return value == true
	end,
	rebirth = function(producer, required: number): boolean
		return producer:getState().player.rebirth >= required
	end,
}

local ConditionsMeta = {
	type = "other",
}
local ConditionsServer: ConditionsServer = table.clone(ConditionsMeta) :: any
local ConditionsClient: ConditionsClient = table.clone(ConditionsMeta) :: any

function ConditionsServer:CheckCondition(player: Player, conditionType: string, value: any): boolean
	local producer = self.path.controller.ServerData:GetPlayerProducerAsync(player):expect()

	return Conditions[conditionType](producer, value, player)
end

function ConditionsClient:CheckCondition(conditionType: string, value: any): boolean
	local producer = self.path.controller.ClientData:GetPlayerProducerAsync():expect()

	return Conditions[conditionType](producer, value)
end

return (isServer and ConditionsServer or ConditionsClient) :: Conditions
