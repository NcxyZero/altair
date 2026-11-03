local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AltairConfig = require(ReplicatedStorage.shared.config.AltairConfig)
local Bifrost = require(ReplicatedStorage.package.Bifrost)
local Bridgenet2 = require(ReplicatedStorage.package.Bridgenet2)
local Logger = require(ReplicatedStorage.util.Core.Logger)

local bridges: { [string]: any } = {} -- bridges this side created; on the server, the only names _GetBridgeFunction confirms

local replicateToServer: RemoteFunction

if RunService:IsClient() then
	replicateToServer = ReplicatedStorage:WaitForChild("_GetBridgeFunction")
end

-- existingOnly returns the bridge only if this side already created it, without creating it or asking the server.
return function(bridgeName: string, existingOnly: boolean?): any
	if bridges[bridgeName] or existingOnly then
		return bridges[bridgeName]
	end

	if RunService:IsServer() then
		bridges[bridgeName] = AltairConfig.UseBridgenet and Bridgenet2.ServerBridge(bridgeName)
			or Bifrost.Bridge(bridgeName)

		return bridges[bridgeName]
	end

	-- The server only confirms bridges it created itself (waiting while it starts up); a client cannot create one.
	local created: boolean = replicateToServer:InvokeServer(bridgeName) == true
	if not created then
		Logger.warn(
			`Bridge "{bridgeName}" was not created by the server, so this client sends and receives nothing through it. Create it on the server during startup, for example with GetBridge("{bridgeName}") at the top of a server module.`
		)
	end

	-- A Bridgenet2 client bridge waits for the server's bridge without limit, so with Bridgenet2 an unconfirmed name
	-- gets a Bifrost bridge instead: it never waits, and no server code listens to it.
	bridges[bridgeName] = AltairConfig.UseBridgenet and created and Bridgenet2.ClientBridge(bridgeName)
		or Bifrost.Bridge(bridgeName)

	return bridges[bridgeName]
end
