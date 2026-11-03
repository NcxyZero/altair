local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Maid = require(ReplicatedStorage.package.Maid)

local ANIMATION_TARGET_ATTRIBUTE: string = "AnimationTarget" -- selects which GuiObject the hover animates
local ICON_HOVER_SIZE_MULTIPLIER: number = 1.05
local ICON_ROTATION_MULTIPLIER: number = 15
local PARENT_ANIMATION_TARGET: string = "Parent" -- AnimationTarget value that animates the parent GuiObject
local TAG_NAME: string = script.Name
local UI_SCALE_NAME: string = "UIScale" -- the UIScale ButtonAnimation also scales, so both aim at the same base

type IconState = {
	baseRotation: number,
	baseScale: number,
	icon: GuiObject,
	uiScale: UIScale,
}

export type IconHoverAnimation = {
	AddIcon: (self: IconHoverAnimation, icon: GuiObject, previousIconStates: { IconState }) -> (),
	Destroy: (self: IconHoverAnimation) -> (),
	MouseEnter: (self: IconHoverAnimation) -> (),
	MouseLeave: (self: IconHoverAnimation) -> (),
	ResolveIcons: (self: IconHoverAnimation) -> (),
	VerifyChange: (self: IconHoverAnimation) -> (),
	new: (instance: GuiObject) -> IconHoverAnimation,
	__index: IconHoverAnimation,
	iconStates: { IconState },
	iconName: string,
	tag: string,
	type: string,
	iconObjectValue: ObjectValue?,
	instance: GuiObject,
	maid: Maid.Maid,
}

local IconHoverAnimation: IconHoverAnimation = {} :: IconHoverAnimation
IconHoverAnimation.__index = IconHoverAnimation
IconHoverAnimation.type = "local_tag"
IconHoverAnimation.tag = TAG_NAME

function IconHoverAnimation.new(instance: GuiObject): IconHoverAnimation
	local self = setmetatable({}, IconHoverAnimation)
	self.instance = instance
	self.maid = Maid.new()
	self.iconName = (instance:GetAttribute("IconName") :: string) or "Icon"
	self.iconStates = {}

	for _index: number, child: Instance in instance:GetChildren() do
		if child.Name == self.iconName and child:IsA("ObjectValue") then
			self.iconObjectValue = child

			break
		end
	end

	self:ResolveIcons()

	local iconObjectValue: ObjectValue? = self.iconObjectValue
	if self.iconStates[1] == nil and not iconObjectValue then
		return self
	end

	self.maid:GiveTask(instance.MouseEnter:Connect(function(): ()
		self:MouseEnter()
	end))

	self.maid:GiveTask(instance.MouseLeave:Connect(function(): ()
		self:MouseLeave()
	end))

	if iconObjectValue then
		self.maid:GiveTask(iconObjectValue:GetPropertyChangedSignal("Value"):Connect(function(): ()
			self:VerifyChange()
		end))
	end

	return self
end

function IconHoverAnimation:ResolveIcons(): ()
	local previousIconStates: { IconState } = self.iconStates
	local parent: Instance? = self.instance.Parent

	self.iconStates = {}

	local usesParentTarget: boolean = self.instance:GetAttribute(ANIMATION_TARGET_ATTRIBUTE) == PARENT_ANIMATION_TARGET
	if usesParentTarget and parent and parent:IsA("GuiObject") then
		self:AddIcon(parent, previousIconStates)

		return
	end

	local iconObjectValue: ObjectValue? = self.iconObjectValue
	local linkedIcon: Instance? = iconObjectValue and iconObjectValue.Value
	if linkedIcon and linkedIcon:IsA("GuiObject") then
		self:AddIcon(linkedIcon, previousIconStates)
	end

	for _index: number, child: Instance in self.instance:GetChildren() do
		if child.Name == self.iconName and child:IsA("GuiObject") then
			self:AddIcon(child, previousIconStates)

			break
		end
	end

	local sibling: Instance? = parent and parent:FindFirstChild(self.instance.Name .. self.iconName)
	if sibling and sibling:IsA("GuiObject") then
		self:AddIcon(sibling, previousIconStates)
	end
end

function IconHoverAnimation:AddIcon(icon: GuiObject, previousIconStates: { IconState }): ()
	for index: number = 1, #self.iconStates do
		if self.iconStates[index].icon == icon then
			return
		end
	end

	-- an icon kept by VerifyChange may still be mid-tween, so it keeps the base values captured before
	for index: number = 1, #previousIconStates do
		local previousIconState: IconState = previousIconStates[index]
		if previousIconState.icon == icon and previousIconState.uiScale.Parent == icon then
			table.insert(self.iconStates, previousIconState)

			return
		end
	end

	-- the size only changes through the UIScale: scaling Size would drop its Offset and stack with ButtonAnimation
	local uiScale: UIScale = icon:FindFirstChild(UI_SCALE_NAME) :: any
	if not uiScale or not uiScale:IsA("UIScale") then
		local newUIScale: UIScale = Instance.new("UIScale")
		newUIScale.Name = UI_SCALE_NAME
		newUIScale.Parent = icon

		uiScale = newUIScale
	end

	table.insert(self.iconStates, {
		baseRotation = icon.Rotation,
		baseScale = uiScale.Scale,
		icon = icon,
		uiScale = uiScale,
	})
end

function IconHoverAnimation:MouseEnter(): ()
	local iconStates: { IconState } = self.iconStates
	if iconStates[1] == nil then
		return
	end

	for index: number = 1, #iconStates do
		local iconState: IconState = iconStates[index]
		local scaleTween: Tween = TweenService:Create(
			iconState.uiScale,
			TweenInfo.new(0.1, Enum.EasingStyle.Linear),
			{ Scale = iconState.baseScale * ICON_HOVER_SIZE_MULTIPLIER }
		)
		scaleTween:Play()
	end

	-- the swing is relative to each icon's authored rotation and ends back on it
	task.spawn(function(): ()
		for step: number = -1, 1, 1 do
			task.wait(0.05)

			for index: number = 1, #iconStates do
				local iconState: IconState = iconStates[index]
				local rotationTween: Tween = TweenService:Create(
					iconState.icon,
					TweenInfo.new(0.1),
					{ Rotation = iconState.baseRotation + step * ICON_ROTATION_MULTIPLIER }
				)
				rotationTween:Play()
			end
		end

		task.wait(0.1)

		for index: number = 1, #iconStates do
			local iconState: IconState = iconStates[index]
			local finalRotationTween: Tween =
				TweenService:Create(iconState.icon, TweenInfo.new(0.1), { Rotation = iconState.baseRotation })
			finalRotationTween:Play()
		end
	end)
end

function IconHoverAnimation:MouseLeave(): ()
	local iconStates: { IconState } = self.iconStates
	for index: number = 1, #iconStates do
		local iconState: IconState = iconStates[index]
		local scaleTween: Tween = TweenService:Create(
			iconState.uiScale,
			TweenInfo.new(0.1, Enum.EasingStyle.Linear),
			{ Scale = iconState.baseScale }
		)
		scaleTween:Play()
	end
end

-- the linked icon changed: the current icons return to their base scale and the hover follows the new icon
function IconHoverAnimation:VerifyChange(): ()
	self:MouseLeave()
	self:ResolveIcons()
end

function IconHoverAnimation:Destroy(): ()
	self.maid:DoCleaning()
end

return IconHoverAnimation
