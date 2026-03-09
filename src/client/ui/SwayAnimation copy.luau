local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)

export type Default = {
	amplitude: number,
	isOffsetEnabled: boolean,
	offsetAmplitude: number,
	speed: number,
	tag: string,
	type: string,
	instance: GuiObject,
	path: InitializerTypes.ClientPath,
	maid: Maid.Maid,
	__index: Default,
	new: (instance: TextLabel, path: InitializerTypes.ClientPath) -> Default,
	Animate: (self: Default) -> (),
	Destroy: (self: Default) -> (),
}

local SwayAnimation: Default = {} :: Default
SwayAnimation.__index = SwayAnimation
SwayAnimation.type = "local_tag"
SwayAnimation.tag = script.Name

local DEFAULT_ROTATION_AMPLITUDE: number = 6 -- degrees of gentle sway
local DEFAULT_OFFSET_AMPLITUDE: number = 4 -- pixels of floating sway
local DEFAULT_SPEED: number = 0.5 -- cycles per second
local TWO_PI: number = math.pi * 2

function SwayAnimation.new(instance: TextLabel, path: InitializerTypes.ClientPath): Default
	local self = setmetatable({}, SwayAnimation)
	self.instance = instance
	self.path = path
	self.maid = Maid.new()
	self.amplitude = instance:GetAttribute("SwayRotation") or DEFAULT_ROTATION_AMPLITUDE
	self.offsetAmplitude = instance:GetAttribute("SwayOffset") or DEFAULT_OFFSET_AMPLITUDE
	self.isOffsetEnabled = instance:GetAttribute("SwayOffsetEnabled")
	self.speed = instance:GetAttribute("SwaySpeed") or DEFAULT_SPEED

	self:Animate()

	return self
end

function SwayAnimation:Animate(): ()
	local baseRotation: number = self.instance.Rotation
	local basePosition: UDim2 = self.instance.Position
	local phaseOffset: number = math.random() * TWO_PI

	self.maid:GiveTask(RunService.Heartbeat:Connect(function(): ()
		local phase: number = os.clock() * self.speed * TWO_PI + phaseOffset
		local sway: number = math.sin(phase)

		self.instance.Rotation = baseRotation + sway * self.amplitude

		if not self.isOffsetEnabled then
			return
		end

		local xScale: number = basePosition.X.Scale
		local xOffset: number = basePosition.X.Offset
		local yScale: number = basePosition.Y.Scale
		local yOffset: number = basePosition.Y.Offset + math.cos(phase) * self.offsetAmplitude

		self.instance.Position = UDim2.new(xScale, xOffset, yScale, yOffset)
	end))
end

function SwayAnimation:Destroy(): ()
	self.maid:DoCleaning()
end

return SwayAnimation
