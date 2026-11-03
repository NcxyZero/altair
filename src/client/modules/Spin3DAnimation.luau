local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)

export type Spin3DAnimation = {
	basePivot: CFrame,
	basePosition: Vector3,
	instance: PVInstance,
	maid: Maid.Maid,
	path: InitializerTypes.ClientPath,
	progress: number,
	speed: number,
	tag: string,
	type: string,
	__index: Spin3DAnimation,
	new: (instance: Instance, path: InitializerTypes.ClientPath) -> Spin3DAnimation?,
	Destroy: (self: Spin3DAnimation) -> (),
	Render: (self: Spin3DAnimation, delta: number) -> (),
}

local Spin3DAnimation: Spin3DAnimation = {} :: any
Spin3DAnimation.__index = Spin3DAnimation
Spin3DAnimation.type = "tag"
Spin3DAnimation.tag = script.Name

local DEFAULT_ANIMATION_SPEED: number = 20 -- degrees per second, matching SpinAnimation

local function getFiniteNumberAttribute(instance: Instance, attributeName: string): number?
	local value: unknown = instance:GetAttribute(attributeName)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return
	end

	return value
end

function Spin3DAnimation.new(instance: Instance, path: InitializerTypes.ClientPath): Spin3DAnimation?
	if not instance:IsA("BasePart") and not instance:IsA("Model") then
		return
	end

	local speed: number? = getFiniteNumberAttribute(instance, "Spin3DSpeed")
	local fallbackSpeed: number? = getFiniteNumberAttribute(instance, "AnimationSpeed")
	local phase: number? = getFiniteNumberAttribute(instance, "Spin3DPhase")

	local self: Spin3DAnimation = setmetatable({}, Spin3DAnimation) :: any
	self.basePivot = (instance :: any):GetPivot()
	self.basePosition = self.basePivot.Position
	self.instance = instance :: any
	self.path = path
	self.maid = Maid.new()
	self.progress = phase and phase % 360 or 0
	self.speed = speed or fallbackSpeed or DEFAULT_ANIMATION_SPEED

	return self
end

function Spin3DAnimation:Render(delta: number): ()
	self.progress += self.speed * delta
	self.progress %= 360

	local currentPivot: CFrame = self.instance:GetPivot()
	local currentOffset: Vector3 = currentPivot.Position - self.basePosition
	local rotation: CFrame = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(self.progress))

	self.instance:PivotTo(CFrame.new(currentOffset) * self.basePivot * rotation)
end

function Spin3DAnimation:Destroy(): ()
	self.maid:DoCleaning()
	self.instance:PivotTo(self.basePivot)
end

return Spin3DAnimation
