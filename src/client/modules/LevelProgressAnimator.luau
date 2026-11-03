local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Maid = require(ReplicatedStorage.package.Maid)

export type LevelProgressAnimator = {
	ApplyProgress: (self: LevelProgressAnimator) -> (),
	Destroy: (self: LevelProgressAnimator) -> (),
	SetImmediate: (self: LevelProgressAnimator, level: number, progress: number) -> (),
	SetTarget: (self: LevelProgressAnimator, level: number, progress: number) -> (),
	Step: (self: LevelProgressAnimator, deltaTime: number) -> (),
	new: (
		fill: GuiObject,
		responsiveness: number,
		onDisplayedLevelChanged: (level: number) -> (),
		onLevelReset: (() -> ())?
	) -> LevelProgressAnimator,
	__index: LevelProgressAnimator,
	currentProgress: number,
	displayedLevel: number,
	isAnimating: boolean,
	pendingLevelReset: boolean,
	responsiveness: number,
	targetLevel: number,
	targetProgress: number,
	velocity: number,
	xOffset: number,
	yOffset: number,
	yScale: number,
	onDisplayedLevelChanged: (level: number) -> (),
	onLevelReset: (() -> ())?,
	fill: GuiObject,
	maid: Maid.Maid,
}

local LevelProgressAnimator: LevelProgressAnimator = {} :: any
LevelProgressAnimator.__index = LevelProgressAnimator

local PROGRESS_SETTLE_THRESHOLD: number = 0.001 -- lets a completed level visibly reach its endpoint
local VELOCITY_SETTLE_THRESHOLD: number = 0.005 -- prevents a spring tail from delaying the level reset

function LevelProgressAnimator.new(
	fill: GuiObject,
	responsiveness: number,
	onDisplayedLevelChanged: (level: number) -> (),
	onLevelReset: (() -> ())?
): LevelProgressAnimator
	local self: LevelProgressAnimator = setmetatable({}, LevelProgressAnimator) :: any
	self.currentProgress = math.clamp(fill.Size.X.Scale, 0, 1)
	self.displayedLevel = 1
	self.fill = fill
	self.isAnimating = false
	self.maid = Maid.new()
	self.onDisplayedLevelChanged = onDisplayedLevelChanged
	self.onLevelReset = onLevelReset
	self.pendingLevelReset = false
	self.responsiveness = math.max(responsiveness, 0.001)
	self.targetLevel = 1
	self.targetProgress = self.currentProgress
	self.velocity = 0
	self.xOffset = fill.Size.X.Offset
	self.yOffset = fill.Size.Y.Offset
	self.yScale = fill.Size.Y.Scale

	self.maid:GiveTask(RunService.PreRender:Connect(function(deltaTime: number): ()
		self:Step(deltaTime)
	end))

	return self
end

function LevelProgressAnimator:ApplyProgress(): ()
	self.fill.Size = UDim2.new(self.currentProgress, self.xOffset, self.yScale, self.yOffset)
end

function LevelProgressAnimator:SetImmediate(level: number, progress: number): ()
	local normalizedLevel: number = math.max(level // 1, 1)
	local normalizedProgress: number = math.clamp(progress, 0, 1)

	self.currentProgress = normalizedProgress
	self.displayedLevel = normalizedLevel
	self.isAnimating = false
	self.pendingLevelReset = false
	self.targetLevel = normalizedLevel
	self.targetProgress = normalizedProgress
	self.velocity = 0

	self:ApplyProgress()
	self.onDisplayedLevelChanged(normalizedLevel)
end

function LevelProgressAnimator:SetTarget(level: number, progress: number): ()
	local normalizedLevel: number = math.max(level // 1, 1)
	local normalizedProgress: number = math.clamp(progress, 0, 1)
	if normalizedLevel < self.displayedLevel then
		self:SetImmediate(normalizedLevel, normalizedProgress)

		return
	end

	self.targetLevel = normalizedLevel
	self.targetProgress = normalizedProgress
	self.isAnimating = true

	if normalizedLevel <= self.displayedLevel then
		self.pendingLevelReset = false
	end
end

function LevelProgressAnimator:Step(deltaTime: number): ()
	if not self.isAnimating then
		return
	end

	if self.pendingLevelReset then
		self.currentProgress = 0
		self.displayedLevel = self.targetLevel
		self.pendingLevelReset = false
		self.velocity = 0

		self:ApplyProgress()
		self.onDisplayedLevelChanged(self.displayedLevel)
		if self.onLevelReset then
			self.onLevelReset()
		end

		return
	end

	local isCompletingLevel: boolean = self.displayedLevel < self.targetLevel
	local desiredProgress: number = isCompletingLevel and 1 or self.targetProgress
	local displacement: number = self.currentProgress - desiredProgress
	local stepDeltaTime: number = math.min(deltaTime, 0.1)
	local decay: number = math.exp(-self.responsiveness * stepDeltaTime)
	local velocityOffset: number = (self.velocity + self.responsiveness * displacement) * stepDeltaTime

	self.currentProgress = desiredProgress + (displacement + velocityOffset) * decay
	self.velocity = (self.velocity - self.responsiveness * velocityOffset) * decay

	if self.currentProgress <= 0 then
		self.currentProgress = 0
		self.velocity = math.max(self.velocity, 0)
	elseif self.currentProgress >= 1 then
		self.currentProgress = 1
		self.velocity = math.min(self.velocity, 0)
	end

	if
		isCompletingLevel
		and math.abs(1 - self.currentProgress) <= PROGRESS_SETTLE_THRESHOLD
		and math.abs(self.velocity) <= VELOCITY_SETTLE_THRESHOLD
	then
		self.currentProgress = 1
		self.pendingLevelReset = true
		self.velocity = 0
	elseif
		not isCompletingLevel
		and math.abs(desiredProgress - self.currentProgress) <= PROGRESS_SETTLE_THRESHOLD
		and math.abs(self.velocity) <= VELOCITY_SETTLE_THRESHOLD
	then
		self.currentProgress = desiredProgress
		self.isAnimating = false
		self.velocity = 0
	end

	self:ApplyProgress()
end

function LevelProgressAnimator:Destroy(): ()
	self.maid:DoCleaning()
end

return LevelProgressAnimator
