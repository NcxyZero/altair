local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Maid = require(ReplicatedStorage.package.Maid)

export type Button3DAnimation = {
	type: string,
	tag: string,
	instance: BasePart,
	maid: Maid.Maid,
	__index: Button3DAnimation,
	new: (instance: BasePart, path: any) -> Button3DAnimation,
	Destroy: (self: Button3DAnimation) -> (),
	Animate: (self: Button3DAnimation) -> (),
	Cancel: (self: Button3DAnimation) -> (),
}

local Button3DAnimation: Button3DAnimation = {} :: any
Button3DAnimation.__index = Button3DAnimation
Button3DAnimation.type = "tag"
Button3DAnimation.tag = script.Name

local SHRINK_MULTIPLIER: number = 0.85 -- determines how much the button shrinks on press
local DARKEN_MULTIPLIER: number = 0.35 -- determines how much the color darkens on press
local SHRINK_TIME: number = 0.1 -- seconds
local GROW_TIME: number = 0.25 -- seconds

function Button3DAnimation.new(instance: BasePart, path: any): Button3DAnimation
	local self = setmetatable({}, Button3DAnimation)
	self.instance = instance
	self.path = path
	self.maid = Maid.new()

	self.originalSize = instance.Size
	self.originalColor = instance.Color
	self.shrinkTween = nil
	self.growTween = nil

	return self
end

local function cancelTweens(self: any): ()
	local shrink: Tween? = self.shrinkTween
	local grow: Tween? = self.growTween

	if shrink then
		shrink:Cancel()
		self.shrinkTween = nil
	end

	if grow then
		grow:Cancel()
		self.growTween = nil
	end
end

function Button3DAnimation:Cancel(): ()
	cancelTweens(self)
end

function Button3DAnimation:Animate(): ()
	local button: BasePart = self.instance
	if not button or not button:IsA("BasePart") then
		return
	end

	cancelTweens(self)

	local shrinkSize: Vector3 = self.originalSize * (Vector3.one * SHRINK_MULTIPLIER)
	local darkerColor: Color3 = Color3.new(
		self.originalColor.R * DARKEN_MULTIPLIER,
		self.originalColor.G * DARKEN_MULTIPLIER,
		self.originalColor.B * DARKEN_MULTIPLIER
	)

	local shrinkTween: Tween = TweenService:Create(
		button,
		TweenInfo.new(SHRINK_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Size = shrinkSize, Color = darkerColor }
	)
	self.shrinkTween = shrinkTween

	local growTween: Tween = TweenService:Create(
		button,
		TweenInfo.new(GROW_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Size = self.originalSize, Color = self.originalColor }
	)
	self.growTween = growTween

	self.maid:GiveTask(shrinkTween.Completed:Connect(function(): ()
		if self.shrinkTween ~= shrinkTween then
			return
		end

		if button.Parent then
			growTween:Play()
		else
			self.shrinkTween = nil
			self.growTween = nil
		end
	end))

	self.maid:GiveTask(growTween.Completed:Connect(function(): ()
		if self.growTween == growTween then
			self.shrinkTween = nil
			self.growTween = nil
		end
	end))

	shrinkTween:Play()
end

function Button3DAnimation:Destroy(): ()
	cancelTweens(self)
	self.maid:DoCleaning()
end

return Button3DAnimation
