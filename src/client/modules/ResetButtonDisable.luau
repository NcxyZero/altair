local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)

local ResetButtonDisable = {}
ResetButtonDisable.type = "controller"

function ResetButtonDisable:Init(): ()
	pcall(function(): ()
		StarterGui:SetCore("ResetButtonCallback", GameConfig.core.resetButtonDisable)
	end)
end

return ResetButtonDisable
