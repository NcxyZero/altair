--BIFROST ONLY
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bifrost = require(ReplicatedStorage.package.Bifrost)
local Logger = require(ReplicatedStorage.util.Core.Logger)

local bridges: { [string]: any } = {} -- function bridges this side created; on the server, the only names _REPLICATE_BRIDGE_FUNCTION confirms

local replicateToServer: Bifrost.ClientFunctionBridge

if RunService:IsClient() then
	replicateToServer = Bifrost.FunctionBridge("_REPLICATE_BRIDGE_FUNCTION") :: any
end

-- existingOnly returns the function bridge only if this side already created it, without creating it or asking the server.
return function(bridgeName: string, existingOnly: boolean?): any
	if bridges[bridgeName] or existingOnly then
		return bridges[bridgeName]
	end

	bridges[bridgeName] = Bifrost.FunctionBridge(bridgeName)

	if RunService:IsServer() then
		return bridges[bridgeName]
	end

	-- The server only confirms function bridges it created itself (waiting while it starts up); a client cannot create one.
	local created: boolean = replicateToServer:Invoke(bridgeName) == true
	if not created then
		Logger.warn(
			`Function bridge "{bridgeName}" was not created by the server, so invoking it fails. Create it on the server during startup with GetFunctionBridge("{bridgeName}") and give it an OnInvoke handler.`
		)
	end

	return bridges[bridgeName]
end
