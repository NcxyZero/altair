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
	isFloating: boolean,
	floatBaseCFrame: CFrame?,
	floatMaid: Maid.Maid,
	originalWhileAnimating: CFrame?,
	maid: Maid.Maid,
	animationMaid: Maid.Maid,
	__index: BasicJumpAnimation,
	new: (instance: Instance) -> BasicJumpAnimation,
	Destroy: (self: BasicJumpAnimation) -> (),
	Animate: (self: BasicJumpAnimation) -> (),
	Cancel: (self: BasicJumpAnimation) -> (),
	StartFloating: (self: BasicJumpAnimation) -> (),
	StopFloating: (self: BasicJumpAnimation) -> (),
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

local FLOAT_BASE_LIFT_MULTIPLIER: number = 0.15
local FLOAT_AMPLITUDE_MULTIPLIER: number = 0.08
local FLOAT_MIN_BASE_LIFT: number = 0.35
local FLOAT_MIN_AMPLITUDE: number = 0.18
local FLOAT_SPEED: number = 1.35
local FLOAT_SINH_NORMALIZER: number = math.sinh(1)
local RETURN_TO_FLOAT_SECONDS: number = 0.18

type FloatEntry = {
	baseLiftY: number,
	amplitudeY: number,
}

local floatingByClass: { [BasicJumpAnimation]: FloatEntry } = setmetatable({}, { __mode = "k" }) :: any
local floatingTime: number = 0
local floatingHeartbeat: RBXScriptConnection? = nil

local function stopFloatingHeartbeatIfEmpty(): ()
	if next(floatingByClass) ~= nil then
		return
	end

	if floatingHeartbeat then
		floatingHeartbeat:Disconnect()
		floatingHeartbeat = nil
	end
end

local function ensureFloatingHeartbeat(): ()
	if floatingHeartbeat then
		return
	end

	floatingHeartbeat = RunService.Heartbeat:Connect(function(deltaTime: number): ()
		if next(floatingByClass) == nil then
			stopFloatingHeartbeatIfEmpty()

			return
		end

		floatingTime += deltaTime * FLOAT_SPEED

		local normalized: number = math.sinh(math.sin(floatingTime)) / FLOAT_SINH_NORMALIZER

		local current: BasicJumpAnimation? = next(floatingByClass)
		while current do
			local nextClass: BasicJumpAnimation? = next(floatingByClass, current)

			local entry: FloatEntry? = floatingByClass[current]
			local target: Instance? = current and current.instance
			if not entry or not target or not target.Parent then
				floatingByClass[current] = nil
				if current then
					current.isFloating = false
					current.floatBaseCFrame = nil
				end
			elseif not current.isAnimating then
				local currentBase: CFrame? = current.floatBaseCFrame
				if currentBase then
					local yOffset: number = entry.baseLiftY + entry.amplitudeY * normalized
					local basePos: Vector3 = currentBase.Position + Vector3.yAxis * yOffset
					local baseRot: CFrame = currentBase - currentBase.Position
					local newCFrame: CFrame = CFrame.new(basePos) * baseRot

					SetInstanceCFrame(target, newCFrame)
				end
			end

			current = nextClass
		end

		stopFloatingHeartbeatIfEmpty()
	end)
end

local function getTargetVisualHeight(target: Instance): number
	if target:IsA("BasePart") then
		return target.Size.Y
	end

	if target:IsA("Model") then
		return target:GetExtentsSize().Y
	end

	return 1
end

local function cancelTweens(self: any): ()
	if self.animationMaid then
		self.animationMaid:DoCleaning()
	end

	self.isAnimating = false
end

local function getFloatTargetCFrame(self: BasicJumpAnimation, baseCFrame: CFrame): CFrame
	local entry: FloatEntry? = floatingByClass[self]
	if not entry then
		return baseCFrame
	end

	local normalized: number = math.sinh(math.sin(floatingTime)) / FLOAT_SINH_NORMALIZER
	local yOffset: number = entry.baseLiftY + entry.amplitudeY * normalized
	local basePos: Vector3 = baseCFrame.Position + Vector3.yAxis * yOffset
	local baseRot: CFrame = baseCFrame - baseCFrame.Position

	return CFrame.new(basePos) * baseRot
end

function BasicJumpAnimation:StartFloating(): ()
	if self.isFloating then
		return
	end

	local target: Instance = self.instance
	if not target or not target.Parent then
		return
	end

	local baseCFrame: CFrame? = GetInstanceCFrame(target)
	if not baseCFrame then
		return
	end

	self.isFloating = true
	self.floatBaseCFrame = baseCFrame

	local targetHeight: number = getTargetVisualHeight(target)
	local baseLiftY: number = math.max(FLOAT_MIN_BASE_LIFT, targetHeight * FLOAT_BASE_LIFT_MULTIPLIER)
	local amplitudeY: number = math.max(FLOAT_MIN_AMPLITUDE, targetHeight * FLOAT_AMPLITUDE_MULTIPLIER)

	self.floatMaid:DoCleaning()
	self.floatMaid:GiveTask(function(): ()
		floatingByClass[self] = nil

		stopFloatingHeartbeatIfEmpty()
	end)

	floatingByClass[self] = {
		baseLiftY = baseLiftY,
		amplitudeY = amplitudeY,
	}

	ensureFloatingHeartbeat()
end

function BasicJumpAnimation:StopFloating(): ()
	if not self.isFloating then
		return
	end

	self.isFloating = false
	self.floatBaseCFrame = nil
	self.floatMaid:DoCleaning()
	stopFloatingHeartbeatIfEmpty()
end

function BasicJumpAnimation.new(instance: Instance, path: any): BasicJumpAnimation
	local self = setmetatable({}, BasicJumpAnimation)
	self.instance = instance
	self.path = path
	self.maid = Maid.new()
	self.animationMaid = Maid.new()
	self.floatMaid = Maid.new()

	self.isAnimating = false
	self.isFloating = false
	self.floatBaseCFrame = nil
	self.originalWhileAnimating = nil

	if RunService:IsClient() then
		if instance.Name == "StandModel" or instance:GetAttribute("ModelName") ~= nil then
			self:StartFloating()
		end
	end

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

	local originalCFrame: CFrame? = self.floatBaseCFrame or GetInstanceCFrame(target)
	if not originalCFrame then
		return
	end

	if self.isFloating then
		self.floatBaseCFrame = originalCFrame
		SetInstanceCFrame(target, originalCFrame)
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
	local isReturning: boolean = false
	local returnProgress: number = 0
	local returnStart: CFrame = originalCFrame

	self.animationMaid:GiveTask(RunService.Heartbeat:Connect(function(deltaTime: number): ()
		if not target.Parent then
			cancelTweens(self)

			return
		end

		if isReturning then
			returnProgress += deltaTime
			local alpha: number = math.clamp(returnProgress / RETURN_TO_FLOAT_SECONDS, 0, 1)
			local eased: number = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			local baseForFloat: CFrame = (self.floatBaseCFrame or originalCFrame)
			local returnTarget: CFrame = (self.isFloating and getFloatTargetCFrame(self, baseForFloat))
				or originalCFrame
			local newCFrame: CFrame = returnStart:Lerp(returnTarget, eased)

			SetInstanceCFrame(target, newCFrame)

			if highlight.Parent then
				highlight.OutlineTransparency = 1 - (1 - alpha) * 0.85
			end

			if alpha >= 1 then
				SetInstanceCFrame(target, returnTarget)
				cancelTweens(self)
			end

			return
		end

		progress += deltaTime * 2
		local alpha: number = math.sin(progress)
		if progress >= math.pi / 2 then
			returnStart = GetInstanceCFrame(target) or originalCFrame
			isReturning = true
			returnProgress = 0

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
	self:StopFloating()
	self.maid:DoCleaning()
end

return BasicJumpAnimation
