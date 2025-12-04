local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
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

local PRESS_DEPTH_MULTIPLIER: number = 0.5
local PRESS_TIME: number = 0.08
local RELEASE_TIME: number = 0.3

function Button3DAnimation.new(instance: BasePart, path: any): Button3DAnimation
	local self = setmetatable({}, Button3DAnimation)
	self.instance = instance
	self.path = path
	self.maid = Maid.new()

	self.shrinkTween = nil
	self.growTween = nil
	self.growColorTween = nil

	return self
end

local function cancelTweens(self: any): ()
	local shrink: Tween = self.shrinkTween
	local grow: Tween = self.growTween
	local growColor: Tween = self.growColorTween

	if shrink then
		shrink:Cancel()
		self.shrinkTween = nil
	end

	if grow then
		grow:Cancel()
		self.growTween = nil
	end

	if growColor then
		growColor:Cancel()
		self.growColorTween = nil
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

	button:SetAttribute("RaycastIgnore", true)
	SoundService:PlayLocalSound(SoundService.LocalEffects.ButtonStep)

	local originalCFrame: CFrame = button.CFrame
	local originalColor: Color3 = button.Color

	local pressDirection: Vector3 = -originalCFrame.UpVector
	local pressDepth: number = math.max(0.05, button.Size.Y * PRESS_DEPTH_MULTIPLIER)
	local pressedCFrame: CFrame = originalCFrame + pressDirection * pressDepth
	local whiteColor: Color3 = Color3.new(1, 1, 1)

	local shrinkTween: Tween = TweenService:Create(
		button,
		TweenInfo.new(PRESS_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ CFrame = pressedCFrame, Color = whiteColor }
	)
	self.shrinkTween = shrinkTween

	local growTween: Tween = TweenService:Create(
		button,
		TweenInfo.new(RELEASE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ CFrame = originalCFrame }
	)
	self.growTween = growTween

	local growColorTween: Tween = TweenService:Create(
		button,
		TweenInfo.new(RELEASE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Color = originalColor }
	)
	self.growColorTween = growColorTween

	self.maid:GiveTask(shrinkTween.Completed:Connect(function(): ()
		if self.shrinkTween ~= shrinkTween then
			return
		end

		if button.Parent then
			growTween:Play()
			growColorTween:Play()
		else
			self.shrinkTween = nil
			self.growTween = nil
			self.growColorTween = nil
		end
	end))

	local posDone: boolean = false
	local colorDone: boolean = false

	local function tryFinish(): ()
		if posDone and colorDone then
			self.shrinkTween = nil
			self.growTween = nil
			self.growColorTween = nil

			button:SetAttribute("RaycastIgnore")
		end
	end

	self.maid:GiveTask(growTween.Completed:Connect(function(): ()
		if self.growTween == growTween then
			posDone = true
			tryFinish()
		end
	end))

	self.maid:GiveTask(growColorTween.Completed:Connect(function(): ()
		if self.growColorTween == growColorTween then
			colorDone = true
			tryFinish()
		end
	end))

	shrinkTween:Play()
end

function Button3DAnimation:Destroy(): ()
	cancelTweens(self)
	self.maid:DoCleaning()
end

return Button3DAnimation
