local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GetInstanceCFrame = require(ReplicatedStorage.util.GetInstanceCFrame)
local Maid = require(ReplicatedStorage.package.Maid)
local SetInstanceCFrame = require(ReplicatedStorage.util.SetInstanceCFrame)

export type BasicJumpAnimation = {
	type: string,
	tag: string,
	instance: Instance,
	isAnimating: boolean,
	originalWhileAnimating: CFrame?,
	maid: Maid.Maid,
	animationMaid: Maid.Maid,
	__index: BasicJumpAnimation,
	new: (instance: Instance) -> BasicJumpAnimation,
	Destroy: (self: BasicJumpAnimation) -> (),
	Animate: (self: BasicJumpAnimation) -> (),
	Cancel: (self: BasicJumpAnimation) -> (),
	computeCFrame: (
		self: BasicJumpAnimation,
		originalCFrame: CFrame,
		height: number,
		t: number,
		alpha: number
	) -> CFrame,
}

local BasicJumpAnimation: BasicJumpAnimation = {} :: any
BasicJumpAnimation.__index = BasicJumpAnimation
BasicJumpAnimation.type = "tag"
BasicJumpAnimation.tag = script.Name

local JUMP_HEIGHT_MULTIPLIER: number = 0.5
local MAX_TILT_RADIANS: number = math.rad(12)

local function cancelTweens(self: any): ()
	if self.animationMaid then
		self.animationMaid:DoCleaning()
	end

	self.isAnimating = false
end

function BasicJumpAnimation.new(instance: Instance, path: any): BasicJumpAnimation
	local self = setmetatable({}, BasicJumpAnimation)
	self.instance = instance
	self.path = path
	self.maid = Maid.new()
	self.animationMaid = Maid.new()

	self.isAnimating = false
	self.originalWhileAnimating = nil

	return self
end

function BasicJumpAnimation:Cancel(): ()
	if self.originalWhileAnimating and self.instance and self.instance.Parent then
		SetInstanceCFrame(self.instance, self.originalWhileAnimating)
	end

	cancelTweens(self)
end

function BasicJumpAnimation:Animate(): ()
	local target: Instance = self.instance
	if not target or not target.Parent then
		return
	end

	if self.isAnimating then
		return
	end

	local originalCFrame: CFrame? = GetInstanceCFrame(target)
	if not originalCFrame then
		return
	end

	local height: number = JUMP_HEIGHT_MULTIPLIER
	if target:IsA("BasePart") then
		height = math.max(0.3, target.Size.Y * JUMP_HEIGHT_MULTIPLIER)
	elseif target:IsA("Model") then
		local extents: Vector3 = target:GetExtentsSize()
		height = math.max(0.6, extents.Y * JUMP_HEIGHT_MULTIPLIER)
	end

	self.isAnimating = true
	self.originalWhileAnimating = originalCFrame

	local highlight: Highlight = Instance.new("Highlight") :: any
	highlight.Name = "JumpHighlight"
	highlight.Adornee = target
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.new(1, 1, 0)
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.new(1, 1, 0)
	highlight.OutlineTransparency = 1
	highlight.Parent = target

	self.animationMaid:GiveTask(highlight)
	local progress: number = (math.pi / 2) / 90

	self.animationMaid:GiveTask(RunService.Heartbeat:Connect(function(deltaTime: number): ()
		if not target.Parent then
			cancelTweens(self)

			return
		end

		progress += deltaTime * 2
		local alpha: number = math.sin(progress)
		if progress >= math.pi / 2 then
			SetInstanceCFrame(target, originalCFrame)
			cancelTweens(self)

			return
		end

		local posOffsetY: number = math.sin(math.pi * alpha) * height

		local tiltScale: number = TweenService:GetValue(progress, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
		local tilt: number = math.sin(math.pi * alpha) * MAX_TILT_RADIANS * tiltScale

		local basePos: Vector3 = originalCFrame.Position + Vector3.yAxis * posOffsetY
		local baseRot: CFrame = (originalCFrame - originalCFrame.Position) * CFrame.fromAxisAngle(Vector3.xAxis, tilt)
		local newCFrame: CFrame = CFrame.new(basePos) * baseRot

		SetInstanceCFrame(target, newCFrame)

		local pulse: number = math.sin(math.pi * alpha)
		local outlineStrength: number = math.clamp(pulse ^ 0.5, 0, 1) * 0.85

		if highlight.Parent then
			highlight.OutlineTransparency = 1 - outlineStrength
		end
	end))
end

function BasicJumpAnimation:Destroy(): ()
	cancelTweens(self)
	self.maid:DoCleaning()
end

return BasicJumpAnimation
