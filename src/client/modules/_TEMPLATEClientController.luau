local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.util.Logger)

export type Default = {
	index: number?,
	type: string?,
	path: { any },
	Init: () -> (),
}

local ControllerTemplate: Default = {} :: Default
ControllerTemplate.type = "controller"
-- ControllerTemplate.index = math.random()

function ControllerTemplate:Init(): ()
	Logger.print("ServerControllerTemplate initalized")
end

return ControllerTemplate
