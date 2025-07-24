local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

local Bridgenet2 = require(ReplicatedStorage.package.Bridgenet2)

local bridges = {}

return function(bridgeName: string)
	if bridges[bridgeName] then
		return bridges[bridgeName]
	end

	if RunService:IsServer() then
		bridges[bridgeName] = Bridgenet2.ServerBridge(bridgeName)
	else
		bridges[bridgeName] = Bridgenet2.ClientBridge(bridgeName)
	end

	return bridges[bridgeName]
end
