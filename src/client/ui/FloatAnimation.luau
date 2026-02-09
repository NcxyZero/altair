local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)

export type FloatAnimation = {
	animationTime: number,
	currentTween: Tween?,
	floatThread: thread?,
	instance: GuiObject,
	maid: Maid.Maid,
	maxPosition: UDim2,
	minPosition: UDim2,
	path: InitializerTypes.ClientPath,
	tag: string,
	type: string,
	__index: FloatAnimation,
	new: (instance: GuiObject, path: InitializerTypes.ClientPath) -> FloatAnimation?,
	Start: (self: FloatAnimation) -> (),
	Destroy: (self: FloatAnimation) -> (),
}

local FloatAnimation: FloatAnimation = {} :: any
FloatAnimation.__index = FloatAnimation
FloatAnimation.type = "local_tag"
FloatAnimation.tag = script.Name

local DEFAULT_ANIMATION_TIME: number = 1
local DEFAULT_FLOAT_OFFSET: number = 24

local function createOffset(basePosition: UDim2, offsetY: number): UDim2
	return UDim2.new(basePosition.X.Scale, basePosition.X.Offset, basePosition.Y.Scale, basePosition.Y.Offset + offsetY)
end

function FloatAnimation.new(instance: GuiObject, path: InitializerTypes.ClientPath): FloatAnimation?
	local minPosition: UDim2? = instance:GetAttribute("Min") :: any
	local maxPosition: UDim2? = instance:GetAttribute("Max") :: any
	local basePosition: UDim2 = minPosition or maxPosition or instance.Position
	local resolvedMin: UDim2 = minPosition or basePosition
	local resolvedMax: UDim2 = maxPosition or createOffset(basePosition, -DEFAULT_FLOAT_OFFSET)

	if not minPosition and maxPosition then
		resolvedMin = createOffset(basePosition, DEFAULT_FLOAT_OFFSET)
	end

	local self = setmetatable({}, FloatAnimation)
	self.instance = instance
	self.path = path
	self.maid = Maid.new()
	self.animationTime = instance:GetAttribute("AnimationTime") or DEFAULT_ANIMATION_TIME
	self.minPosition = resolvedMin
	self.maxPosition = resolvedMax

	self:Start()

	return self
end

function FloatAnimation:Start(): ()
	self.instance.Position = self.minPosition

	local tweenInfo: TweenInfo = TweenInfo.new(self.animationTime, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	local isActive: boolean = true

	self.floatThread = task.spawn(function(): ()
		while isActive do
			local tweenToMax: Tween = TweenService:Create(self.instance, tweenInfo, { Position = self.maxPosition })
			self.currentTween = tweenToMax
			tweenToMax:Play()

			tweenToMax.Completed:Wait()
			if not isActive then
				break
			end

			local tweenToMin: Tween = TweenService:Create(self.instance, tweenInfo, { Position = self.minPosition })
			self.currentTween = tweenToMin
			tweenToMin:Play()

			tweenToMin.Completed:Wait()
		end
	end)

	self.maid:GiveTask(function(): ()
		isActive = false

		if self.floatThread then
			task.cancel(self.floatThread)

			self.floatThread = nil
		end

		if self.currentTween then
			self.currentTween:Cancel()

			self.currentTween = nil
		end
	end)
end

function FloatAnimation:Destroy(): ()
	self.maid:DoCleaning()
end

return FloatAnimation
