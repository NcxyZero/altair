local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)

export type FloatAnimation = {
	amplitude: number,
	basePosition: UDim2,
	instance: GuiObject,
	isHorizontal: boolean,
	isOffsetAmplitude: boolean,
	maid: Maid.Maid,
	path: InitializerTypes.ClientPath,
	progress: number,
	speed: number,
	tag: string,
	type: string,
	__index: FloatAnimation,
	new: (instance: GuiObject, path: InitializerTypes.ClientPath) -> FloatAnimation?,
	Render: (self: FloatAnimation, delta: number) -> (),
	Destroy: (self: FloatAnimation) -> (),
}

local FloatAnimation: FloatAnimation = {} :: any
FloatAnimation.__index = FloatAnimation
FloatAnimation.type = "local_tag"
FloatAnimation.tag = script.Name

local DEFAULT_FLOAT_SPEED: number = 3 -- radians per second; Render runs once per frame from main.client
local DEFAULT_FLOAT_AMPLITUDE: number = 0.1
local FULL_ROTATION: number = 2 * math.pi -- radians in one float cycle

local function getFiniteNumberAttribute(instance: Instance, attributeName: string): number?
	local value: unknown = instance:GetAttribute(attributeName)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return
	end

	return value
end

function FloatAnimation.new(instance: GuiObject, path: InitializerTypes.ClientPath): FloatAnimation?
	local self: FloatAnimation = setmetatable({}, FloatAnimation) :: any
	local horizontalAttribute: boolean? = instance:GetAttribute("Horizontal") :: boolean?
	local offsetAmplitude: number? = getFiniteNumberAttribute(instance, "FloatOffsetAmplitude")
	local scaleAmplitude: number? = getFiniteNumberAttribute(instance, "FloatAmplitude")
	local phase: number? = getFiniteNumberAttribute(instance, "FloatPhase")
	local speed: number? = getFiniteNumberAttribute(instance, "FloatSpeed")

	self.amplitude = math.abs(offsetAmplitude or scaleAmplitude or DEFAULT_FLOAT_AMPLITUDE)
	self.basePosition = instance.Position
	self.instance = instance
	self.isOffsetAmplitude = offsetAmplitude ~= nil
	self.path = path
	self.maid = Maid.new()
	self.isHorizontal = not not horizontalAttribute
	self.progress = phase and phase % FULL_ROTATION or math.random() * FULL_ROTATION
	self.speed = speed and math.max(speed, 0) or DEFAULT_FLOAT_SPEED

	return self
end

function FloatAnimation:Render(delta: number): ()
	self.progress += delta * self.speed
	self.progress %= FULL_ROTATION

	local offset: number = math.sin(self.progress) * self.amplitude
	local basePosition: UDim2 = self.basePosition
	if self.isOffsetAmplitude then
		if self.isHorizontal then
			self.instance.Position = UDim2.new(
				basePosition.X.Scale,
				basePosition.X.Offset + offset,
				basePosition.Y.Scale,
				basePosition.Y.Offset
			)

			return
		end

		self.instance.Position =
			UDim2.new(basePosition.X.Scale, basePosition.X.Offset, basePosition.Y.Scale, basePosition.Y.Offset + offset)

		return
	end

	if self.isHorizontal then
		self.instance.Position =
			UDim2.new(basePosition.X.Scale + offset, basePosition.X.Offset, basePosition.Y.Scale, basePosition.Y.Offset)

		return
	end

	self.instance.Position =
		UDim2.new(basePosition.X.Scale, basePosition.X.Offset, basePosition.Y.Scale + offset, basePosition.Y.Offset)
end

function FloatAnimation:Destroy(): ()
	self.maid:DoCleaning()

	self.instance.Position = self.basePosition
end

return FloatAnimation
