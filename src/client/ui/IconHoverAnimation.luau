local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--local AnchorPointAdjustments = require(ReplicatedStorage.util.AnchorPointAdjustments)

local LocalPlayer = require(ReplicatedStorage.util.LocalPlayer)
local Maid = require(ReplicatedStorage.package.Maid)

local ICON_HOVER_SIZE_MULTIPLIER: number = 1.05
local ICON_ROTATION_MULTIPLIER: number = 15
local TAG_NAME: string = script.Name

local objectValue: ObjectValue = LocalPlayer:FindFirstChild(TAG_NAME) :: ObjectValue
if not objectValue then
	local newObjectValue: ObjectValue = Instance.new("ObjectValue")
	newObjectValue.Name = TAG_NAME
	newObjectValue.Parent = LocalPlayer
	objectValue = newObjectValue
end

export type IconHoverAnimation = {
	type: string,
	tag: string,
	icons: { GuiObject }?,
	iconOriginalSizes: { UDim2 }?,
	iconOriginalScales: { number }?,
	instance: GuiObject,
	maid: Maid.Maid,
	valueMaid: Maid.Maid,

	__index: IconHoverAnimation,
	new: (instance: GuiObject) -> IconHoverAnimation,
	MouseEnter: (self: IconHoverAnimation) -> (),
	MouseLeave: (self: IconHoverAnimation) -> (),
	VerifyChange: (self: IconHoverAnimation) -> (),
	Destroy: (self: IconHoverAnimation) -> (),
}

local IconHoverAnimation: IconHoverAnimation = {} :: IconHoverAnimation
IconHoverAnimation.__index = IconHoverAnimation
IconHoverAnimation.type = "local_tag"
IconHoverAnimation.tag = TAG_NAME

function IconHoverAnimation.new(instance: GuiObject): IconHoverAnimation
	local self = setmetatable({}, IconHoverAnimation)
	self.instance = instance
	self.maid = Maid.new()
	self.valueMaid = Maid.new()
	self.icons = {}
	self.iconOriginalSizes = {}
	self.iconOriginalScales = {}

	local name: string = (instance:GetAttribute("IconName") :: string) or "Icon"

	local function addIcon(icon: GuiObject): ()
		local icons: { GuiObject } = self.icons :: { GuiObject }
		for index = 1, #icons do
			if icons[index] == icon then
				return
			end
		end

		table.insert(icons, icon)
		table.insert(self.iconOriginalSizes :: { UDim2 }, icon.Size)

		local uiScale: UIScale? = icon:FindFirstChild("UIScale") :: UIScale
		local baseScale: number = 0
		if uiScale then
			baseScale = uiScale.Scale
		end
		table.insert(self.iconOriginalScales :: { number }, baseScale)
	end

	local iconObjectValue: ObjectValue? = nil
	for _index: number, child: Instance in instance:GetChildren() do
		if child.Name == name and child:IsA("ObjectValue") then
			iconObjectValue = child
			break
		end
	end

	if iconObjectValue and iconObjectValue.Value and iconObjectValue.Value:IsA("GuiObject") then
		addIcon(iconObjectValue.Value :: GuiObject)
	end

	for _index: number, child: Instance in instance:GetChildren() do
		if child.Name == name and child:IsA("GuiObject") then
			addIcon(child :: GuiObject)
			break
		end
	end

	local parent: Instance? = instance.Parent
	if parent then
		local sibling: Instance? = parent:FindFirstChild(instance.Name .. name)
		if sibling and sibling:IsA("GuiObject") then
			addIcon(sibling :: GuiObject)
		end
	end

	if (self.icons :: { GuiObject })[1] == nil then
		return self
	end

	self.maid:GiveTask(instance.MouseEnter:Connect(function(): ()
		self:MouseEnter()
	end))

	self.maid:GiveTask(instance.MouseLeave:Connect(function(): ()
		self:MouseLeave()
	end))

	if iconObjectValue then
		self.valueMaid:GiveTask(iconObjectValue:GetPropertyChangedSignal("Value"):Connect(function(): ()
			self:VerifyChange()
		end))
	end

	return self
end

function IconHoverAnimation:MouseEnter(): ()
	local icons: { GuiObject } = self.icons or {}
	local originals: { UDim2 } = self.iconOriginalSizes or {}
	local originalScales: { number } = self.iconOriginalScales or {}
	if icons[1] == nil then
		return
	end

	objectValue.Value = self.instance

	for index = 1, #icons do
		local icon: GuiObject = icons[index]
		local baseScale: number = originalScales[index] or 0
		if baseScale > 0 then
			local uiScale: UIScale? = icon:FindFirstChild("UIScale") :: UIScale
			if uiScale then
				local target: number = baseScale * ICON_HOVER_SIZE_MULTIPLIER
				local tween: Tween = TweenService:Create(
					uiScale :: UIScale,
					TweenInfo.new(0.1, Enum.EasingStyle.Linear),
					{ Scale = target }
				)
				tween:Play()
			else
				local original: UDim2 = originals[index]
				local endSize: UDim2 = UDim2.fromScale(
					original.X.Scale * ICON_HOVER_SIZE_MULTIPLIER,
					original.Y.Scale * ICON_HOVER_SIZE_MULTIPLIER
				)
				--AnchorPointAdjustments:AdjustPosition(icon, Vector2.one / 2)
				local sizeTween: Tween =
					TweenService:Create(icon, TweenInfo.new(0.1, Enum.EasingStyle.Linear), { Size = endSize })
				sizeTween:Play()
			end
		else
			local original: UDim2 = originals[index]
			local endSize: UDim2 = UDim2.fromScale(
				original.X.Scale * ICON_HOVER_SIZE_MULTIPLIER,
				original.Y.Scale * ICON_HOVER_SIZE_MULTIPLIER
			)
			--AnchorPointAdjustments:AdjustPosition(icon, Vector2.one / 2)
			local sizeTween: Tween =
				TweenService:Create(icon, TweenInfo.new(0.1, Enum.EasingStyle.Linear), { Size = endSize })
			sizeTween:Play()
		end
	end

	task.spawn(function(): ()
		for step = -1, 1, 1 do
			task.wait(0.05)

			for index = 1, #icons do
				local icon: GuiObject = icons[index]
				local rotationTween: Tween =
					TweenService:Create(icon, TweenInfo.new(0.1), { Rotation = step * ICON_ROTATION_MULTIPLIER })
				rotationTween:Play()
			end
		end

		task.wait(0.1)

		for index = 1, #icons do
			local icon: GuiObject = icons[index]
			local finalRotationTween: Tween = TweenService:Create(icon, TweenInfo.new(0.1), { Rotation = 0 })
			finalRotationTween:Play()
		end
	end)
end

function IconHoverAnimation:MouseLeave(): ()
	local icons: { GuiObject } = self.icons or {}
	local originals: { UDim2 } = self.iconOriginalSizes or {}
	local originalScales: { number } = self.iconOriginalScales or {}
	if icons[1] == nil then
		return
	end

	for index = 1, #icons do
		local icon: GuiObject = icons[index]
		local baseScale: number = originalScales[index] or 0
		if baseScale > 0 then
			local uiScale: UIScale? = icon:FindFirstChild("UIScale") :: UIScale
			if uiScale then
				local tween: Tween = TweenService:Create(
					uiScale :: UIScale,
					TweenInfo.new(0.1, Enum.EasingStyle.Linear),
					{ Scale = baseScale }
				)
				tween:Play()
			else
				local original: UDim2 = originals[index]
				local sizeTween: Tween =
					TweenService:Create(icon, TweenInfo.new(0.1, Enum.EasingStyle.Linear), { Size = original })
				sizeTween:Play()
			end
		else
			local original: UDim2 = originals[index]
			local sizeTween: Tween =
				TweenService:Create(icon, TweenInfo.new(0.1, Enum.EasingStyle.Linear), { Size = original })
			sizeTween:Play()
		end
	end
end

function IconHoverAnimation:VerifyChange(): ()
	if objectValue.Value ~= self.instance then
		self.valueMaid:DoCleaning()
		self:MouseLeave()
	end
end

function IconHoverAnimation:Destroy(): ()
	self.maid:DoCleaning()
	self.valueMaid:DoCleaning()
end

return IconHoverAnimation
