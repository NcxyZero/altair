local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

local AltairConfig = require(ReplicatedStorage.shared.config.AltairConfig)
local Bifrost = require(ReplicatedStorage.package.Bifrost)
local Bridgenet2 = require(ReplicatedStorage.package.Bridgenet2)
local replicateToServer: RemoteFunction

if RunService:IsClient() then
	replicateToServer = ReplicatedStorage:WaitForChild("_GetBridgeFunction")
end

local bridges = {}

return function(bridgeName: string)
	if bridges[bridgeName] then
		return bridges[bridgeName]
	end

	if RunService:IsServer() then
		bridges[bridgeName] = AltairConfig.UseBridgenet and Bridgenet2.ServerBridge(bridgeName)
			or Bifrost.Bridge(bridgeName)
	else
		replicateToServer:InvokeServer(bridgeName)
		bridges[bridgeName] = AltairConfig.UseBridgenet and Bridgenet2.ClientBridge(bridgeName)
			or Bifrost.Bridge(bridgeName)
	end

	return bridges[bridgeName]
end
