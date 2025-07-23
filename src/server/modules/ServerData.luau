export type Default = {
	index: number,
	type: string,
	gameData: {},
	profiles: {},
	PlayerAdded: (self: Default, player: Player) -> (),
	PlayerRemoving: (self: Default, player: Player) -> (),
	Init: () -> (),
}

local ServerData: Default = {} :: Default
ServerData.index = 0
ServerData.type = "controller"
ServerData.profiles = {}
ServerData.gameData = {}

function ServerData:PlayerAdded(player: Player): ()
	--
end

function ServerData:PlayerRemoving(player: Player): ()
	--
end

function ServerData:Init()
	--
end

return ServerData
