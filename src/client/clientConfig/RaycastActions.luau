local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CooldownManager = require(ReplicatedStorage.shared.modules.CooldownManager)
local GetBridge = require(ReplicatedStorage.util.Core.GetBridge)
local Logger = require(ReplicatedStorage.util.Core.Logger)
local NotificationUI = require(ReplicatedStorage.client.ui.NotificationUI)
local OpenGui = require(ReplicatedStorage.util.Core.OpenGui)
local TagManager = require(ReplicatedStorage.shared.modules.TagManager)

local MonetizationPrompt = GetBridge("MonetizationPrompt")

local function safeRequireUiModule(uiName: string, actionName: string): any?
	local clientFolder: Instance? = ReplicatedStorage:FindFirstChild("client")
	local uiFolder: Instance? = clientFolder and clientFolder:FindFirstChild("ui")
	if not uiFolder then
		Logger.warn(`No UI folder found in ReplicatedStorage for action {actionName}!`)

		return
	end

	local moduleScript: Instance? = uiFolder:FindFirstChild(uiName)
	if not moduleScript then
		Logger.warn(`No UI ModuleScript found with name "{uiName}" for action {actionName}!`)

		return
	end

	if not moduleScript:IsA("ModuleScript") then
		Logger.warn(
			`UI object "{uiName}" is not a ModuleScript (got {moduleScript.ClassName}) for action {actionName}!`
		)
		return
	end

	local ok: boolean, result: any = xpcall(require, Logger.warn, moduleScript)
	if not ok then
		Logger.warn(`Failed to require UI module "{uiName}" for action {actionName}: {result}`)

		return
	end

	return result
end

local RaycastActions = {
	Notification = function(instance: Instance, leaving: boolean?): boolean?
		if leaving then
			return
		end

		local raycastActionValue: string = instance:GetAttribute("RaycastActionValue") :: string
		if not raycastActionValue then
			Logger.warn(`No RaycastActionValue attribute found on instance "{instance}" for action Notification!`)

			return
		end

		if not CooldownManager:IsReady("Notification") then
			return
		end

		local secondsAttribute: unknown = instance:GetAttribute("seconds")
		local seconds: number = typeof(secondsAttribute) == "number" and math.max(0, secondsAttribute) or 3

		CooldownManager:Set("Notification", seconds + 2)

		local payload: any = {
			text = raycastActionValue,
		}

		for key: string, value: any in instance:GetAttributes() do
			if key:find("^RaycastAction") then
				continue
			end

			payload[key] = value
		end

		NotificationUI.Send(payload)

		return true
	end,

	OpenWindow = function(instance: Instance, leaving: boolean?): boolean?
		local raycastActionValue: string = instance:GetAttribute("RaycastActionValue") :: string
		if not raycastActionValue then
			Logger.warn(`No RaycastActionValue attribute found on instance "{instance}" for action OpenWindow!`)
			return
		end

		local module: any? = safeRequireUiModule(raycastActionValue, "OpenWindow")
		if not module then
			return
		end

		local target: any = TagManager:FindLocalTagClass(raycastActionValue) or module

		local openArg: any = instance:GetAttribute("RaycastActionArg")

		if not leaving then
			OpenGui:Open(target, openArg)

			return true
		else
			OpenGui:Close(target)

			return false
		end
	end,

	PromptPurchase = function(instance: Instance, leaving: boolean?): boolean?
		if leaving then
			return
		end

		local name: string = instance:GetAttribute("RaycastActionValue") :: string
		if not name then
			Logger.warn(`No RaycastActionValue attribute found on instance "{instance}" for action PromptPurchase!`)

			return
		end

		local productName: string? = instance:GetAttribute("RaycastActionArg") :: any
		local isGamePass: boolean = instance:GetAttribute("IsGamePass") == true

		if not CooldownManager:IsReady("PromptPurchase") then
			return
		end
		CooldownManager:Set("PromptPurchase", 1)

		MonetizationPrompt:Fire({
			name = name,
			productName = productName,
			isGamePass = isGamePass,
		})

		return true
	end,
}

return RaycastActions
