local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AnchorPointAdjustments = require(ReplicatedStorage.util.AnchorPointAdjustments)
local Maid = require(ReplicatedStorage.package.Maid)

local LocalPlayer: Player & { [unknown]: ObjectValue } = Players.LocalPlayer

local ICON_HOVER_SIZE_MULTIPLIER: number = 1.05
local ICON_ROTATION_MULTIPLIER: number = 15
local TAG_NAME: string = script.Name

local objectValue: ObjectValue = LocalPlayer:FindFirstChild(TAG_NAME) :: ObjectValue
if not objectValue then
	local newObjectValue: ObjectValue = Instance.new("ObjectValue")
	newObjectValue.Name = TAG_NAME
	newObjectValue.Parent = LocalPlayer
	objectValue = newObjectValue -- dlaczego tak? typy..
end

export type IconHoverAnimation = {
	type: string,
	tag: string,
	instance: GuiObject,
	maid: Maid.Maid,
	valueMaid: Maid.Maid,
	icon: GuiObject?,
	iconOriginalSize: UDim2?,

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
	self.icon = nil
	self.iconOriginalSize = nil

	local iconObjectValue: ObjectValue? = nil
	for _index: number, child: Instance in instance:GetChildren() do
		if child.Name == "Icon" and child:IsA("ObjectValue") then
			iconObjectValue = child
			break
		end
	end

	if not iconObjectValue or not iconObjectValue.Value then
		return self
	end

	self.icon = iconObjectValue.Value :: GuiObject
	self.iconOriginalSize = self.icon.Size

	self.maid:GiveTask(instance.MouseEnter:Connect(function(): ()
		self:MouseEnter()
	end))

	self.maid:GiveTask(instance.MouseLeave:Connect(function(): ()
		self:MouseLeave()
	end))

	self.valueMaid:GiveTask(iconObjectValue:GetPropertyChangedSignal("Value"):Connect(function(): ()
		self:VerifyChange()
	end))

	return self
end

function IconHoverAnimation:MouseEnter(): ()
	if not self.icon or not self.iconOriginalSize then
		return
	end

	objectValue.Value = self.instance

	local endSize: UDim2 = UDim2.fromScale(
		self.iconOriginalSize.X.Scale * ICON_HOVER_SIZE_MULTIPLIER,
		self.iconOriginalSize.Y.Scale * ICON_HOVER_SIZE_MULTIPLIER
	)

	AnchorPointAdjustments:AdjustPosition(self.icon, Vector2.one / 2)

	local sizeTween: Tween =
		TweenService:Create(self.icon, TweenInfo.new(0.1, Enum.EasingStyle.Linear), { Size = endSize })
	sizeTween:Play()

	task.spawn(function(): ()
		for index = -1, 1, 1 do
			task.wait(0.05)

			local rotationTween: Tween =
				TweenService:Create(self.icon, TweenInfo.new(0.1), { Rotation = index * ICON_ROTATION_MULTIPLIER })
			rotationTween:Play()
		end

		task.wait(0.1)

		local finalRotationTween: Tween = TweenService:Create(self.icon, TweenInfo.new(0.1), { Rotation = 0 })
		finalRotationTween:Play()
	end)
end

function IconHoverAnimation:MouseLeave(): ()
	if not self.icon or not self.iconOriginalSize then
		return
	end

	local sizeTween: Tween =
		TweenService:Create(self.icon, TweenInfo.new(0.1, Enum.EasingStyle.Linear), { Size = self.iconOriginalSize })
	sizeTween:Play()
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
