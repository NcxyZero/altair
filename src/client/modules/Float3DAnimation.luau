local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)

export type Float3DAnimation = {
	amplitude: number,
	basePivot: CFrame,
	instance: PVInstance,
	maid: Maid.Maid,
	path: InitializerTypes.ClientPath,
	progress: number,
	speed: number,
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
	self.progress = math.random()
	self.basePivot = self.instance:GetPivot()
	self.speed = self.instance:GetAttribute("Float3DSpeed") or DEFAULT_FLOAT_SPEED
	self.amplitude = self.instance:GetAttribute("Float3DAmplitude") or DEFAULT_FLOAT_AMPLITUDE

	self.maid:GiveTask(RunService.PreRender:Connect(function(delta: number): ()
		self:Render(delta)
	end))

	return self
end

function Float3DAnimation:Render(delta: number): ()
	self.progress += delta * self.speed
	self.progress %= 2 * math.pi

	local yOffset: number = math.sin(self.progress) * self.amplitude
	self.instance:PivotTo(CFrame.new(0, yOffset, 0) * self.basePivot)
end

function Float3DAnimation:Destroy(): ()
	self.maid:DoCleaning()
end

return Float3DAnimation
