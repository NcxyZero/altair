local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GetBridge = require(ReplicatedStorage.util.GetBridge)

local bridge = GetBridge("WaitForRespond")

local WaitForRespond = {}
local waiting = {}

local function Remote(
	connection: RBXScriptConnection,
	id: string,
	sentId: string,
	player: Player?,
	sentFrom: Player?
): ()
	if RunService:IsServer() and player ~= sentFrom then
		return
	end

	if sentId ~= id then
		return
	end

	local playerId: string = player and player.Name .. player.UserId
	local saltedId: string = id .. playerId

	local found: number? = table.find(waiting, saltedId)
	if found then
		table.remove(waiting, found)
	end

	connection:Disconnect()
end

function WaitForRespond:Respond(id: string, player: Player?): ()
	if RunService:IsServer() then
		bridge:Fire(player, id)
	else
		bridge:Fire(id)
	end
end

function WaitForRespond:Wait(id: string, player: Player): ()
	local connection: RBXScriptConnection
	if RunService:IsServer() then
		connection = bridge:Connect(function(sentFrom: Player, sentId: string): ()
			Remote(connection, id, sentId, player, sentFrom)
		end)
	else
		connection = bridge:Connect(function(_sentFrom: Player, sentId: string): ()
			Remote(connection, id, sentId)
		end)
	end

	local playerId: string = player.Name .. player.UserId
	local saltedId: string = id .. playerId

	table.insert(waiting, saltedId)

	while table.find(waiting, saltedId) do
		task.wait()
	end

	WaitForRespond:Respond(id, player)
end

return WaitForRespond
