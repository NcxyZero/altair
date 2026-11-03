local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Maid = require(ReplicatedStorage.package.Maid)

export type Button3DAnimation = {
	type: string,
	tag: string,
	isPressed: boolean,
	instance: BasePart,
	restCFrame: CFrame?,
	restColor: Color3?,
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

local BUTTON_CAN_COLLIDE: boolean = false
local BUTTON_STEP_SOUND_NAME: string = "ButtonStep" -- optional Sound in LocalEffects; without it presses stay silent
local LOCAL_EFFECTS_NAME: string = "LocalEffects" -- optional Studio-authored SoundService folder of client-only sounds
local PRESS_DEPTH_MULTIPLIER: number = 0.5
local PRESS_TIME: number = 0.08
local RELEASE_TIME: number = 0.3

local function playButtonStep(): ()
	local localEffects: Instance? = SoundService:FindFirstChild(LOCAL_EFFECTS_NAME)
	local buttonStepSound: Sound = (localEffects and localEffects:FindFirstChild(BUTTON_STEP_SOUND_NAME)) :: any
	if not buttonStepSound or not buttonStepSound:IsA("Sound") then
		return
	end

	SoundService:PlayLocalSound(buttonStepSound)
end

function Button3DAnimation.new(instance: BasePart, path: any): Button3DAnimation
	local self = setmetatable({}, Button3DAnimation)
	self.instance = instance
	self.isPressed = false -- true from a press until its release finishes, while the part is away from its rest pose
	self.path = path
	self.maid = Maid.new()

	self.shrinkTween = nil
	self.growTween = nil
	self.growColorTween = nil

	if instance:IsA("BasePart") then
		instance.CanCollide = BUTTON_CAN_COLLIDE
	end

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

	-- an unfinished press has moved and whitened the part, so its stored rest pose is kept instead of re-read
	if not self.isPressed then
		self.restCFrame = button.CFrame
		self.restColor = button.Color
	end

	cancelTweens(self)

	-- set after cancelling: with immediate signals the cancelled release can finish the previous press
	self.isPressed = true

	button:SetAttribute("RaycastIgnore", true)
	playButtonStep()

	local originalCFrame: CFrame = self.restCFrame :: CFrame
	local originalColor: Color3 = self.restColor :: Color3

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

	-- keyed tasks replace the previous press's connections instead of accumulating them until Destroy
	self.maid.shrinkCompleted = shrinkTween.Completed:Connect(function(): ()
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
	end)

	local posDone: boolean = false
	local colorDone: boolean = false

	local function tryFinish(): ()
		if posDone and colorDone then
			self.isPressed = false
			self.shrinkTween = nil
			self.growTween = nil
			self.growColorTween = nil

			button:SetAttribute("RaycastIgnore")
		end
	end

	self.maid.growCompleted = growTween.Completed:Connect(function(): ()
		if self.growTween == growTween then
			posDone = true
			tryFinish()
		end
	end)

	self.maid.growColorCompleted = growColorTween.Completed:Connect(function(): ()
		if self.growColorTween == growColorTween then
			colorDone = true
			tryFinish()
		end
	end)

	shrinkTween:Play()
end

function Button3DAnimation:Destroy(): ()
	cancelTweens(self)
	self.maid:DoCleaning()
end

return Button3DAnimation
