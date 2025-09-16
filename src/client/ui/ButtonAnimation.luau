local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Maid = require(ReplicatedStorage.package.Maid)
local SFX = require(ReplicatedStorage.util.SFX)

local BUTTON_SIZE_MULTIPLIER: number = 0.9
local TAG_NAME: string = script.Name

export type ButtonAnimation = {
	type: string,
	tag: string,
	instance: GuiButton,
	maid: Maid.Maid,
	uiScale: UIScale,

	__index: ButtonAnimation,
	new: (instance: GuiButton) -> ButtonAnimation,
	Destroy: (self: ButtonAnimation) -> (),
}

local ButtonAnimation: ButtonAnimation = {} :: ButtonAnimation
ButtonAnimation.__index = ButtonAnimation
ButtonAnimation.type = "local_tag"
ButtonAnimation.tag = TAG_NAME

function ButtonAnimation.new(instance: GuiButton): ButtonAnimation
	local self = setmetatable({}, ButtonAnimation)
	self.instance = instance
	self.maid = Maid.new()

	local uiScale: UIScale = Instance.new("UIScale")
	uiScale.Scale = 1
	uiScale.Parent = instance
	self.uiScale = uiScale

	local function Animate(scale: number): ()
		local tween: Tween = TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = scale })
		tween:Play()
	end

	local function InputEnded(): ()
		task.defer(Animate, 1)
	end

	local function InputBegan(): ()
		task.spawn(Animate, BUTTON_SIZE_MULTIPLIER)
		SFX.new(SFX.Sounds.InterfacePress, 0.4, false)
	end

	-- Connect mouse events
	self.maid:GiveTask(instance.MouseButton1Down:Connect(InputBegan))
	self.maid:GiveTask(instance.MouseButton1Up:Connect(InputEnded))
	self.maid:GiveTask(instance.MouseLeave:Connect(InputEnded))
	self.maid:GiveTask(instance.MouseEnter:Connect(function(): ()
		SFX.new(SFX.Sounds.InterfaceClick, 0.4, false)
	end))

	return self
end

function ButtonAnimation:Destroy(): ()
	self.maid:DoCleaning()
end

return ButtonAnimation
