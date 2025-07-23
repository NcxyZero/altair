export type Default = {
    index: number,
    type: string,
    gameData: {},
    profiles: {},
    PlayerAdded: (player: Player) -> (),
    PlayerRemoving: (player: Player) -> (),
    Init: () -> (),
}

local ServerData: Default = {} :: Default
ServerData.index = 0
ServerData.type = "controller"
ServerData.profiles = {}
ServerData.gameData = {}

function ServerData:PlayerAdded()

end

function ServerData:PlayerRemoving()

end

function ServerData:Init()

end

return ServerData