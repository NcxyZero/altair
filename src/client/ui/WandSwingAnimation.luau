local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)

type SwingStep = {
	direction: Enum.EasingDirection,
	duration: number,
	multiplier: number,
}

type SwingGroup = {
	cooldownRemaining: number,
	currentMultiplier: number,
	members: { WandSwingAnimation },
	needsCapture: boolean,
	owner: WandSwingAnimation?,
	pivotAbsolute: Vector2?,
	pivotAncestor: GuiObject?,
	pivotLocal: Vector2?,
	pivotOwner: WandSwingAnimation?,
	previousMultiplier: number,
	random: Random,
	stepElapsed: number,
	stepIndex: number,
}

export type WandSwingAnimation = {
	ApplyMultiplier: (self: WandSwingAnimation, multiplier: number) -> (),
	CaptureBase: (self: WandSwingAnimation, pivotAbsolute: Vector2) -> (),
	CaptureGroup: (self: WandSwingAnimation) -> (),
	Destroy: (self: WandSwingAnimation) -> (),
	GetGroupPivotAbsolute: (self: WandSwingAnimation) -> Vector2,
	GetPivotedPosition: (self: WandSwingAnimation, rotationDelta: number) -> UDim2,
	GetPivotOwner: (self: WandSwingAnimation) -> WandSwingAnimation,
	GetVisualAnchorAbsolute: (self: WandSwingAnimation) -> Vector2,
	IsGroupLayoutReady: (self: WandSwingAnimation) -> boolean,
	IsLayoutReady: (self: WandSwingAnimation) -> boolean,
	Render: (self: WandSwingAnimation, deltaTime: number) -> (),
	Reset: (self: WandSwingAnimation) -> (),
	ResetGroup: (self: WandSwingAnimation) -> (),
	UpdateGroup: (self: WandSwingAnimation, deltaTime: number) -> (),
	new: (instance: GuiObject, path: InitializerTypes.ClientPath) -> WandSwingAnimation,
	__index: WandSwingAnimation,
	group: SwingGroup,
	amplitude: number,
	basePivotOffset: Vector2,
	basePosition: UDim2,
	baseRotation: number,
	cooldownMaximum: number,
	cooldownMinimum: number,
	groupKey: string?,
	isGroupPivot: boolean,
	isDestroyed: boolean,
	path: InitializerTypes.ClientPath,
	tag: string,
	type: string,
	instance: GuiObject,
}

local WandSwingAnimation: WandSwingAnimation = {} :: any
WandSwingAnimation.__index = WandSwingAnimation
WandSwingAnimation.tag = script.Name
WandSwingAnimation.type = "local_tag"

local DEFAULT_AMPLITUDE: number = 16 -- degrees around the authored angle
local DEFAULT_COOLDOWN_MAXIMUM: number = 5 -- seconds between wand-swing bursts
local DEFAULT_COOLDOWN_MINIMUM: number = 3 -- seconds between wand-swing bursts
local SWING_DURATION_MULTIPLIER: number = 2 -- doubles the original burst timing

-- damped burst: each step eases the rotation toward multiplier * amplitude
local SWING_STEPS: { SwingStep } = {
	{
		direction = Enum.EasingDirection.Out,
		duration = 0.06 * SWING_DURATION_MULTIPLIER,
		multiplier = -1,
	},
	{
		direction = Enum.EasingDirection.InOut,
		duration = 0.07 * SWING_DURATION_MULTIPLIER,
		multiplier = 0.7,
	},
	{
		direction = Enum.EasingDirection.InOut,
		duration = 0.09 * SWING_DURATION_MULTIPLIER,
		multiplier = -0.45,
	},
	{
		direction = Enum.EasingDirection.InOut,
		duration = 0.11 * SWING_DURATION_MULTIPLIER,
		multiplier = 0.25,
	},
	{
		direction = Enum.EasingDirection.InOut,
		duration = 0.14 * SWING_DURATION_MULTIPLIER,
		multiplier = -0.1,
	},
	{
		direction = Enum.EasingDirection.Out,
		duration = 0.2 * SWING_DURATION_MULTIPLIER,
		multiplier = 0,
	},
}

local groups: { [string]: SwingGroup } = {} -- shared swing groups by WandSwingGroup attribute

local function getFiniteNumberAttribute(instance: Instance, attributeName: string): number?
	local value: unknown = instance:GetAttribute(attributeName)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return
	end

	return value
end

local function getStringAttribute(instance: Instance, attributeName: string): string?
	local value: unknown = instance:GetAttribute(attributeName)
	if type(value) ~= "string" or value == "" then
		return
	end

	return value
end

local function rotateVector(vector: Vector2, radians: number): Vector2
	local cosine: number = math.cos(radians)
	local sine: number = math.sin(radians)

	return Vector2.new(vector.X * cosine - vector.Y * sine, vector.X * sine + vector.Y * cosine)
end

local function createGroup(): SwingGroup
	return {
		cooldownRemaining = 0,
		currentMultiplier = 0,
		members = {},
		needsCapture = true,
		owner = nil,
		pivotAbsolute = nil,
		pivotAncestor = nil,
		pivotLocal = nil,
		pivotOwner = nil,
		previousMultiplier = 0,
		random = Random.new(),
		stepElapsed = 0,
		stepIndex = 0,
	}
end

local function getGroup(groupKey: string): SwingGroup
	local group: SwingGroup = groups[groupKey]
	if group then
		return group
	end

	local newGroup: SwingGroup = createGroup()
	groups[groupKey] = newGroup

	return newGroup
end

local function getCommonGuiAncestor(members: { WandSwingAnimation }): GuiObject?
	local firstMember: WandSwingAnimation?
	for index: number = 1, #members do
		local member: WandSwingAnimation = members[index]
		if member.isDestroyed or not member.instance.Parent then
			continue
		end

		firstMember = member

		break
	end

	if not firstMember then
		return
	end

	local current: Instance? = firstMember.instance.Parent
	while current do
		if not current:IsA("GuiObject") then
			current = current.Parent

			continue
		end

		local isCommonAncestor: boolean = true
		for index: number = 1, #members do
			local member: WandSwingAnimation = members[index]
			if member.isDestroyed or not member.instance.Parent then
				continue
			end

			if current ~= member.instance and not current:IsAncestorOf(member.instance) then
				isCommonAncestor = false

				break
			end
		end

		if isCommonAncestor then
			return current
		end

		current = current.Parent
	end

	return
end

function WandSwingAnimation.new(instance: GuiObject, path: InitializerTypes.ClientPath): WandSwingAnimation
	local cooldownMinimum: number =
		math.max(getFiniteNumberAttribute(instance, "WandSwingCooldownMinimum") or DEFAULT_COOLDOWN_MINIMUM, 0)
	local cooldownMaximum: number =
		math.max(getFiniteNumberAttribute(instance, "WandSwingCooldownMaximum") or DEFAULT_COOLDOWN_MAXIMUM, 0)
	local groupKey: string? = getStringAttribute(instance, "WandSwingGroup")

	local self: WandSwingAnimation = setmetatable({}, WandSwingAnimation) :: any
	self.amplitude = math.max(getFiniteNumberAttribute(instance, "WandSwingAmplitude") or DEFAULT_AMPLITUDE, 0)
	self.basePivotOffset = Vector2.zero
	self.basePosition = instance.Position
	self.baseRotation = instance.Rotation
	self.cooldownMaximum = math.max(cooldownMinimum, cooldownMaximum)
	self.cooldownMinimum = math.min(cooldownMinimum, cooldownMaximum)
	-- only an explicit WandSwingGroup synchronizes objects; any other object swings alone around its own anchor
	self.group = groupKey and getGroup(groupKey) or createGroup()
	self.groupKey = groupKey
	self.instance = instance
	self.isGroupPivot = instance:GetAttribute("WandSwingGroupPivot") == true
	self.isDestroyed = false
	self.path = path

	table.insert(self.group.members, self)

	self.group.needsCapture = true

	if self.isGroupPivot then
		self.group.pivotOwner = self
	end

	return self
end

function WandSwingAnimation:GetVisualAnchorAbsolute(): Vector2
	local anchorPoint: Vector2 = self.instance.AnchorPoint
	local size: Vector2 = self.instance.AbsoluteSize
	local centerOffset: Vector2 = Vector2.new((0.5 - anchorPoint.X) * size.X, (0.5 - anchorPoint.Y) * size.Y)
	local anchorAbsolute: Vector2 = self.instance.AbsolutePosition
		+ Vector2.new(anchorPoint.X * size.X, anchorPoint.Y * size.Y)

	return anchorAbsolute + centerOffset - rotateVector(centerOffset, math.rad(self.baseRotation))
end

function WandSwingAnimation:CaptureBase(pivotAbsolute: Vector2): ()
	self.basePosition = self.instance.Position
	self.baseRotation = self.instance.Rotation
	self.basePivotOffset = self:GetVisualAnchorAbsolute() - pivotAbsolute
end

function WandSwingAnimation:GetPivotOwner(): WandSwingAnimation
	if self.group.pivotOwner and not self.group.pivotOwner.isDestroyed then
		return self.group.pivotOwner
	end

	for _index: number, member: WandSwingAnimation in self.group.members do
		if member.isDestroyed then
			continue
		end

		if member.isGroupPivot then
			self.group.pivotOwner = member

			return member
		end
	end

	for _index: number, member: WandSwingAnimation in self.group.members do
		if member.isDestroyed then
			continue
		end

		self.group.pivotOwner = member

		return member
	end

	return self
end

function WandSwingAnimation:CaptureGroup(): ()
	local pivotOwner: WandSwingAnimation = self:GetPivotOwner()
	pivotOwner.basePosition = pivotOwner.instance.Position
	pivotOwner.baseRotation = pivotOwner.instance.Rotation

	local pivotAbsolute: Vector2 = pivotOwner:GetVisualAnchorAbsolute()
	self.group.pivotAbsolute = pivotAbsolute
	self.group.pivotAncestor = getCommonGuiAncestor(self.group.members)
	self.group.pivotLocal = self.group.pivotAncestor and pivotAbsolute - self.group.pivotAncestor.AbsolutePosition
		or nil

	for _index: number, member: WandSwingAnimation in self.group.members do
		if member.isDestroyed or not member.instance.Parent then
			continue
		end

		member:CaptureBase(pivotAbsolute)
	end

	self.group.needsCapture = false
end

function WandSwingAnimation:GetGroupPivotAbsolute(): Vector2
	local pivotAncestor: GuiObject? = self.group.pivotAncestor
	local pivotLocal: Vector2? = self.group.pivotLocal
	if pivotAncestor and pivotAncestor.Parent and pivotLocal then
		return pivotAncestor.AbsolutePosition + pivotLocal
	end

	return self.group.pivotAbsolute or self:GetVisualAnchorAbsolute()
end

function WandSwingAnimation:GetPivotedPosition(rotationDelta: number): UDim2
	local parent: Instance? = self.instance.Parent
	if not parent or not parent:IsA("GuiObject") then
		return self.basePosition
	end

	local parentSize: Vector2 = parent.AbsoluteSize
	if parentSize.X == 0 or parentSize.Y == 0 then
		return self.basePosition
	end

	local anchorPoint: Vector2 = self.instance.AnchorPoint
	local size: Vector2 = self.instance.AbsoluteSize
	local centerOffset: Vector2 = Vector2.new((0.5 - anchorPoint.X) * size.X, (0.5 - anchorPoint.Y) * size.Y)
	local groupPivotAbsolute: Vector2 = self:GetGroupPivotAbsolute()
	local rotationDeltaRadians: number = math.rad(rotationDelta)
	local targetRotation: number = self.baseRotation + rotationDelta
	local visualAnchorAbsolute: Vector2 = groupPivotAbsolute + rotateVector(self.basePivotOffset, rotationDeltaRadians)
	local anchorAbsolute: Vector2 = visualAnchorAbsolute
		- centerOffset
		+ rotateVector(centerOffset, math.rad(targetRotation))
	local parentRelativeAnchor: Vector2 = anchorAbsolute - parent.AbsolutePosition

	return UDim2.fromScale(parentRelativeAnchor.X / parentSize.X, parentRelativeAnchor.Y / parentSize.Y)
end

function WandSwingAnimation:ApplyMultiplier(multiplier: number): ()
	local rotationDelta: number = self.amplitude * multiplier

	self.instance.Position = self:GetPivotedPosition(rotationDelta)
	self.instance.Rotation = self.baseRotation + rotationDelta
end

function WandSwingAnimation:IsLayoutReady(): boolean
	local current: Instance? = self.instance
	while current and current:IsA("GuiObject") do
		if not current.Visible then
			return false
		end

		local originalSize: unknown = current:GetAttribute("OgSize")
		if typeof(originalSize) == "UDim2" and current.Size ~= originalSize then
			return false
		end

		current = current.Parent
	end

	return true
end

function WandSwingAnimation:IsGroupLayoutReady(): boolean
	for _index: number, member: WandSwingAnimation in self.group.members do
		if member.isDestroyed then
			continue
		end

		if not member.instance.Parent or not member:IsLayoutReady() then
			return false
		end
	end

	return true
end

function WandSwingAnimation:ResetGroup(): ()
	self.group.cooldownRemaining = 0
	self.group.currentMultiplier = 0
	self.group.needsCapture = true
	self.group.previousMultiplier = 0
	self.group.stepElapsed = 0
	self.group.stepIndex = 0
end

function WandSwingAnimation:UpdateGroup(deltaTime: number): ()
	if not self:IsGroupLayoutReady() then
		self:ResetGroup()

		return
	end

	if self.group.needsCapture then
		self:CaptureGroup()
	end

	if self.group.stepIndex == 0 then
		self.group.cooldownRemaining -= deltaTime
		if self.group.cooldownRemaining > 0 then
			self.group.currentMultiplier = 0

			return
		end

		self.group.stepElapsed = 0
		self.group.stepIndex = 1
	end

	local step: SwingStep? = SWING_STEPS[self.group.stepIndex]
	if not step then
		self.group.cooldownRemaining = self.group.random:NextNumber(self.cooldownMinimum, self.cooldownMaximum)
		self.group.currentMultiplier = 0
		self.group.previousMultiplier = 0
		self.group.stepElapsed = 0
		self.group.stepIndex = 0

		return
	end

	self.group.stepElapsed += math.max(deltaTime, 0)

	local alpha: number = math.clamp(self.group.stepElapsed / step.duration, 0, 1)
	local easedAlpha: number = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, step.direction)
	local multiplier: number = self.group.previousMultiplier
		+ (step.multiplier - self.group.previousMultiplier) * easedAlpha

	self.group.currentMultiplier = multiplier

	if alpha < 1 then
		return
	end

	self.group.previousMultiplier = step.multiplier
	self.group.stepElapsed = 0
	self.group.stepIndex += 1
end

function WandSwingAnimation:Render(deltaTime: number): ()
	if self.isDestroyed or not self.instance.Parent then
		return
	end

	if not self.group.owner or self.group.owner.isDestroyed then
		self.group.owner = self
	end

	if self.group.owner == self then
		self:UpdateGroup(deltaTime)
	end

	if not self:IsLayoutReady() or self.group.needsCapture then
		self:Reset()

		return
	end

	self:ApplyMultiplier(self.group.currentMultiplier)
end

function WandSwingAnimation:Reset(): ()
	self.instance.Position = self.basePosition
	self.instance.Rotation = self.baseRotation
end

function WandSwingAnimation:Destroy(): ()
	self.isDestroyed = true

	self:Reset()

	if self.group.owner == self then
		self.group.owner = nil
	end

	local memberIndex: number? = table.find(self.group.members, self)
	if memberIndex then
		table.remove(self.group.members, memberIndex)
	end

	if self.group.pivotOwner == self then
		self.group.pivotOwner = nil
		self.group.needsCapture = true
	end

	local groupKey: string? = self.groupKey
	if groupKey and #self.group.members == 0 and groups[groupKey] == self.group then
		groups[groupKey] = nil
	end
end

return WandSwingAnimation
