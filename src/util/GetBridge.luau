local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

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
		bridges[bridgeName] = Bridgenet2.ServerBridge(bridgeName)
	else
		replicateToServer:InvokeServer(bridgeName)
		bridges[bridgeName] = Bridgenet2.ClientBridge(bridgeName)
	end

	return bridges[bridgeName]
end
