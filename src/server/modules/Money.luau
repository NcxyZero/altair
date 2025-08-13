local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GetBridge = require(ReplicatedStorage.util.GetBridge)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Logger)
local ServerData = require(ServerScriptService.server.modules.ServerData)

export type Default = {
	index: number?,
	type: string?,
	path: InitializerTypes.ServerPath,
	Init: () -> (),
	PlayerAdded: (self: Default, player: Player) -> (),
}

local ControllerTemplate: Default = {} :: Default
ControllerTemplate.type = "controller"
ControllerTemplate.index = 2

function ControllerTemplate:Init(): ()
	GetBridge("Money"):Connect(function(player: Player)
		local profile = ServerData:GetPlayerProfile(player)

		if not profile then
			return
		end

		profile.producer.secureAddCoins(1)
		print(`Money: {profile.producer:getState().player.coins}`)
	end)
end

function ControllerTemplate:PlayerAdded(player: Player)
	local profile = self.path.controller.ServerData:WaitForPlayerProfile(player):expect()

	print(`gameData`, ServerData.gameProducer:getState())
	print(`Money: {profile.producer:getState().player.coins}`)
end

return ControllerTemplate
