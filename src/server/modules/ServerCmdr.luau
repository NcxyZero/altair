local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Cmdr = require(ReplicatedStorage.package.Cmdr)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)

export type Default = {
	index: number?,
	type: string?,
	path: InitializerTypes.ClientPath,
	Init: (self: Default) -> (),
}

local ServerCmdr: Default = {} :: Default
ServerCmdr.type = "controller"

local cmdrFolder: Folder & any = ServerScriptService.server:WaitForChild("cmdr")

function ServerCmdr:Init(): ()
	Cmdr:RegisterDefaultCommands()
	Cmdr:RegisterCommandsIn(cmdrFolder.commands)
	Cmdr:RegisterHooksIn(cmdrFolder.hooks)
	Cmdr:RegisterTypesIn(cmdrFolder.types)
end

return ServerCmdr
