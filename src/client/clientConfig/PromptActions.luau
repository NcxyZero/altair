local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.util.Logger)
local OpenGui = require(ReplicatedStorage.util.OpenGui)
local TagManager = require(ReplicatedStorage.shared.modules.TagManager)

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

	local ok: boolean, result: any = pcall(require, moduleScript)
	if not ok then
		Logger.warn(`Failed to require UI module "{uiName}" for action {actionName}: {result}`)

		return
	end

	return result
end

local PromptActions = {
	OpenWindow = function(instance: Instance, leaving: boolean?): boolean?
		local promptActionValue: string = instance:GetAttribute("PromptActionValue") :: string
		if not promptActionValue then
			Logger.warn(`No PromptActionValue attribute found on instance "{instance}" for action OpenWindow!`)

			return
		end

		local module: any? = safeRequireUiModule(promptActionValue, "OpenWindow")
		if not module then
			return
		end

		local target: any = TagManager:FindLocalTagClass(promptActionValue) or module

		local openArg: any = instance:GetAttribute("PromptActionArg")

		if not leaving then
			OpenGui:Open(target, openArg)

			return true
		else
			OpenGui:Close(target)

			return false
		end
	end,

	ToggleWindow = function(instance: Instance): boolean?
		local promptActionValue: string = instance:GetAttribute("PromptActionValue") :: string
		if not promptActionValue then
			Logger.warn(`No PromptActionValue attribute found on instance "{instance}" for action OpenWindow!`)

			return
		end

		local module: any? = safeRequireUiModule(promptActionValue, "ToggleWindow")
		if not module then
			return
		end

		local target: any = TagManager:FindLocalTagClass(promptActionValue) or module

		local openArg: any = instance:GetAttribute("PromptActionArg")

		OpenGui:Toggle(target, openArg)

		return true
	end,
}

return PromptActions
