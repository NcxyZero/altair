export type AnchorPointAdjustments = {
	AdjustPosition: (self: AnchorPointAdjustments, guiObject: GuiObject, newAnchorPoint: Vector2) -> (),
}

local AnchorPointAdjustments: AnchorPointAdjustments = {} :: AnchorPointAdjustments

function AnchorPointAdjustments:AdjustPosition(guiObject: GuiObject, newAnchorPoint: Vector2): ()
	local currentAbsolutePosition: Vector2 = guiObject.AbsolutePosition
	local currentAbsoluteSize: Vector2 = guiObject.AbsoluteSize

	local currentAnchorPoint: Vector2 = guiObject.AnchorPoint
	local currentVisualPosition: Vector2 = Vector2.new(
		currentAbsolutePosition.X + (currentAbsoluteSize.X * currentAnchorPoint.X),
		currentAbsolutePosition.Y + (currentAbsoluteSize.Y * currentAnchorPoint.Y)
	)

	guiObject.AnchorPoint = newAnchorPoint

	local newPosition: Vector2 = Vector2.new(
		currentVisualPosition.X - (currentAbsoluteSize.X * newAnchorPoint.X),
		currentVisualPosition.Y - (currentAbsoluteSize.Y * newAnchorPoint.Y)
	)

	local parent: GuiObject? = guiObject.Parent :: GuiObject?
	if parent and parent:IsA("GuiObject") then
		local parentSize: Vector2 = parent.AbsoluteSize
		guiObject.Position = UDim2.fromScale(newPosition.X / parentSize.X, newPosition.Y / parentSize.Y)
	else
		guiObject.Position = UDim2.fromOffset(newPosition.X, newPosition.Y)
	end
end

return AnchorPointAdjustments
