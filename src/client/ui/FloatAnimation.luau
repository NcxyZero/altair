local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)

export type FloatAnimation = {
	instance: GuiObject,
	isHorizontal: boolean,
	maid: Maid.Maid,
	path: InitializerTypes.ClientPath,
	progress: number,
	start: number,
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

local DEFAULT_FLOAT_SPEED: number = 1.5
local DEFAULT_FLOAT_AMPLITUDE: number = 0.1

function FloatAnimation.new(instance: GuiObject, path: InitializerTypes.ClientPath): FloatAnimation?
	local self = setmetatable({}, FloatAnimation)
	self.instance = instance
	self.path = path
	self.maid = Maid.new()
	local horizontalAttribute: boolean? = instance:GetAttribute("Horizontal") :: boolean?
	self.isHorizontal = not not horizontalAttribute
	self.progress = math.random()
	self.start = self.isHorizontal and instance.Position.X.Scale or instance.Position.Y.Scale

	self.maid:GiveTask(RunService.PreRender:Connect(function(delta: number): ()
		self:Render(delta)
	end))

	return self
end

function FloatAnimation:Render(delta: number): ()
	self.progress += delta * DEFAULT_FLOAT_SPEED
	self.progress %= 2 * math.pi

	local offset: number = math.sin(self.progress) * DEFAULT_FLOAT_AMPLITUDE
	if self.isHorizontal then
		self.instance.Position = UDim2.fromScale(self.start + offset, self.instance.Position.Y.Scale)

		return
	end

	self.instance.Position = UDim2.fromScale(self.instance.Position.X.Scale, self.start + offset)
end

function FloatAnimation:Destroy(): ()
	self.maid:DoCleaning()
end

return FloatAnimation
