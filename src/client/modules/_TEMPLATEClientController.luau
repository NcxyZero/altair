local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Logger)

export type Default = {
	index: number?,
	type: string?,
	path: InitializerTypes.ClientPath,
	Init: (self: Default) -> (),
}

local ControllerTemplate: Default = {} :: Default
ControllerTemplate.type = "controller"
-- ControllerTemplate.index = math.random()

function ControllerTemplate:Init(): ()
	Logger.print("ClientControllerTemplate initalized")
end

return ControllerTemplate
