local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local Logger = require(ReplicatedStorage.util.Logger)

local ResetButtonDisable = {}
ResetButtonDisable.type = "controller"

function ResetButtonDisable:Init(): ()
	xpcall(function(): ()
		StarterGui:SetCore("ResetButtonCallback", GameConfig.core.resetButtonDisabled)
	end, Logger.warn)
end

return ResetButtonDisable
