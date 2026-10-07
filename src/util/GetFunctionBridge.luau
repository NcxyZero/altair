--BIFROST ONLY
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Bifrost = require(ReplicatedStorage.package.Bifrost)

local replicateToServer
local bridges = {}
if RunService:IsClient() then
	replicateToServer = Bifrost.FunctionBridge("_REPLICATE_BRIDGE_FUNCTION")
end

return function(bridgeName: string)
	if bridges[bridgeName] then
		return bridges[bridgeName]
	end

	bridges[bridgeName] = Bifrost.FunctionBridge(bridgeName)

	if RunService:IsClient() then
		replicateToServer:Invoke(bridgeName)
	end

	return bridges[bridgeName]
end
