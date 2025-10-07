local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)

local ResetButtonDisable = {}
ResetButtonDisable.type = "controller"

function ResetButtonDisable:Init(): ()
	pcall(function(): ()
		game:GetService("StarterGui"):SetCore("ResetButtonCallback", GameConfig.core.resetButtonDisable)
	end)
end

return ResetButtonDisable
