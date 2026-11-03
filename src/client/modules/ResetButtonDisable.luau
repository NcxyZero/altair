local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local Logger = require(ReplicatedStorage.util.Core.Logger)

local ResetButtonDisable = {}
ResetButtonDisable.type = "controller"

-- ResetButtonCallback = false disables the Reset Character button. With resetButtonDisabled false the callback is
-- left alone, so Roblox's default and any callback the game sets itself stay in place.
function ResetButtonDisable:Init(): ()
	if not GameConfig.core.resetButtonDisabled then
		return
	end

	xpcall(function(): ()
		StarterGui:SetCore("ResetButtonCallback", false)
	end, Logger.warn)
end

return ResetButtonDisable
