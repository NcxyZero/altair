local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)

export type Default = {
	type: string,
	tag: string,
	path: InitializerTypes.ClientPath,
	instance: GuiObject,
	shine: Frame,
	tween: Tween,
	__index: Default,
	new: (instance: TextLabel, path: InitializerTypes.ClientPath) -> Default,
	BuildShineVFX: (self: Default) -> (),
	Animate: (self: Default) -> (),
	Destroy: (self: Default) -> (),
}

local ShineAnimation: Default = {} :: Default
ShineAnimation.__index = ShineAnimation
ShineAnimation.type = "local_tag"
ShineAnimation.tag = "ShineAnimation"

function ShineAnimation.new(instance: TextLabel, path: InitializerTypes.ClientPath): Default
	local self = setmetatable({}, ShineAnimation)
	self.instance = instance
	self.path = path

	self:BuildShineVFX()
	self:Animate()

	return self
end

function ShineAnimation:BuildShineVFX(): ()
	local shine: Frame = Instance.new("Frame")
	shine.Name = "Shine"
	shine.AnchorPoint = Vector2.one / 2
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.LayoutOrder = -1
	shine.Position = UDim2.fromScale(0.5, 0.5)
	shine.Size = UDim2.fromScale(1, 1)
	shine.ZIndex = 6
	shine.Parent = self.instance
	self.shine = shine

	local uIGradient: UIGradient = Instance.new("UIGradient")
	uIGradient.Offset = Vector2.xAxis * -2
	uIGradient.Rotation = 45
	uIGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.108479, 0.4625),
		NumberSequenceKeypoint.new(0.194514, 0.55625),
		NumberSequenceKeypoint.new(1, 1),
	})
	uIGradient.Parent = shine

	local uICorner: UICorner = Instance.new("UICorner")
	uICorner.CornerRadius = UDim.new(0.1)
	uICorner.Parent = shine
end

function ShineAnimation:Animate(): ()
	self.tween = TweenService:Create(
		self.shine.UIGradient,
		TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, false, 2),
		{ Offset = Vector2.xAxis * 2 }
	)
	self.tween:Play()
end

function ShineAnimation:Destroy(): ()
	self.tween:Destroy()
end

return ShineAnimation
