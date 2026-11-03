local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)

export type Float3DAnimation = {
	amplitude: number,
	basePivot: CFrame,
	basePosition: Vector3,
	fromBottom: boolean,
	instance: PVInstance,
	maid: Maid.Maid,
	path: InitializerTypes.ClientPath,
	progress: number,
	speed: number,
	synchronized: boolean,
	tag: string,
	type: string,
	__index: Float3DAnimation,
	new: (instance: Instance, path: InitializerTypes.ClientPath) -> Float3DAnimation?,
	Render: (self: Float3DAnimation, delta: number) -> (),
	Destroy: (self: Float3DAnimation) -> (),
}

local Float3DAnimation: Float3DAnimation = {} :: any
Float3DAnimation.__index = Float3DAnimation
Float3DAnimation.type = "tag"
Float3DAnimation.tag = script.Name

local DEFAULT_FLOAT_AMPLITUDE: number = 0.5
local DEFAULT_FLOAT_SPEED: number = 1.5

function Float3DAnimation.new(instance: Instance, path: InitializerTypes.ClientPath): Float3DAnimation?
	if not instance:IsA("BasePart") and not instance:IsA("Model") then
		return
	end

	local self = setmetatable({}, Float3DAnimation)
	self.instance = instance :: any
	self.path = path
	self.maid = Maid.new()
	self.basePivot = self.instance:GetPivot()
	self.basePosition = self.basePivot.Position
	self.speed = self.instance:GetAttribute("Float3DSpeed") or DEFAULT_FLOAT_SPEED
	self.amplitude = self.instance:GetAttribute("Float3DAmplitude") or DEFAULT_FLOAT_AMPLITUDE
	self.fromBottom = self.instance:GetAttribute("Float3DFromBottom") == true
	self.progress = self.fromBottom and 0 or math.random()
	self.synchronized = self.instance:GetAttribute("Float3DSynchronized") == true

	return self
end

function Float3DAnimation:Render(delta: number): ()
	if self.synchronized then
		self.progress = workspace:GetServerTimeNow() * self.speed
	else
		self.progress += delta * self.speed
	end

	self.progress %= 2 * math.pi

	local yOffset: number = if self.fromBottom
		then (1 - math.cos(self.progress)) * self.amplitude
		else math.sin(self.progress) * self.amplitude
	local currentPivot: CFrame = self.instance:GetPivot()
	local currentRotation: CFrame = currentPivot - currentPivot.Position

	self.instance:PivotTo(CFrame.new(self.basePosition + Vector3.yAxis * yOffset) * currentRotation)
end

function Float3DAnimation:Destroy(): ()
	self.maid:DoCleaning()
	self.instance:PivotTo(self.basePivot)
end

return Float3DAnimation
