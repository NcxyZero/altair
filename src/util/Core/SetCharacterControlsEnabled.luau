local ContextActionService = game:GetService("ContextActionService")

local FREEZE_ACTION: string = "freezeMovement"

local function setCharacterControlsEnabled(enabled: boolean): ()
	if enabled then
		ContextActionService:UnbindAction(FREEZE_ACTION)
	else
		ContextActionService:BindAction(FREEZE_ACTION, function(): Enum.ContextActionResult?
			return Enum.ContextActionResult.Sink
		end, false, unpack(Enum.PlayerActions:GetEnumItems()))
	end
end

return setCharacterControlsEnabled
