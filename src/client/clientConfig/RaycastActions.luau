local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.util.Logger)
local OpenGui = require(ReplicatedStorage.util.OpenGui)

local RaycastActions = {
	OpenWindow = function(instance: Instance, leaving: boolean?): boolean?
		local raycastActionValue: string = instance:GetAttribute("RaycastActionValue") :: string
		if not raycastActionValue then
			Logger.warn(`No RaycastActionValue attribute found on instance "{instance}" for action OpenWindow!`)
			return
		end

		local module = require(ReplicatedStorage.client.ui:FindFirstChild(raycastActionValue))
		if not module then
			Logger.warn(`No UI module found with RaycastActionValue "{raycastActionValue}" for action OpenWindow!`)
			return
		end

		if not leaving then
			OpenGui:Open(module)
			return true
		else
			OpenGui:Close(module)
			return false
		end
	end,
}

return RaycastActions
