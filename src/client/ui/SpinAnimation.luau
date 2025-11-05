local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)

export type Default = {
	type: string,
	tag: string,
	path: InitializerTypes.ClientPath,
	instance: GuiObject,
	animationSpeed: number,
	maid: Maid.Maid,
	__index: Default,
	new: (instance: TextLabel, path: InitializerTypes.ClientPath) -> Default,
	Animate: (self: Default) -> (),
	Destroy: (self: Default) -> (),
}

local SpinAnimation: Default = {} :: Default
SpinAnimation.__index = SpinAnimation
SpinAnimation.type = "local_tag"
SpinAnimation.tag = "SpinAnimation"
SpinAnimation.animationSpeed = 20 -- default when no attribute is set

function SpinAnimation.new(instance: TextLabel, path: InitializerTypes.ClientPath): Default
	local self = setmetatable({}, SpinAnimation)
	self.instance = instance
	self.path = path
	self.maid = Maid.new()
	self.animationSpeed = instance:GetAttribute("AnimationSpeed") or self.animationSpeed

	self:Animate()

	return self
end

function SpinAnimation:Animate(): ()
	self.maid:GiveTask(RunService.Heartbeat:Connect(function(deltaTime: number): ()
		local rotation: number = self.instance.Rotation
		rotation += self.animationSpeed * deltaTime
		rotation %= 360
		self.instance.Rotation = rotation
	end))
end

function SpinAnimation:Destroy(): ()
	self.maid:DoCleaning()
end

return SpinAnimation
