local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

return function(): boolean
	return UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and not UserInputService.MouseEnabled
		and not GuiService:IsTenFootInterface()
end
