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

	local originalScalesByElement: { [GuiObject]: number } = {}
	local function Animate(scale: number): ()
		local collection: { GuiObject } = { instance }
		local parent: Instance? = instance.Parent
		local shadow: GuiObject? = (
			instance:FindFirstChild(instance.Name .. "Shadow")
			or instance:FindFirstChild(instance.Name .. "Background")
			or (parent and parent:FindFirstChild(instance.Name .. "Shadow"))
			or (parent and parent:FindFirstChild(instance.Name .. "Background"))
		) :: GuiObject
		if shadow and shadow:IsA("GuiObject") and not shadow:HasTag(TAG_NAME) then
			table.insert(collection, shadow)
		end

		for _index: number, element: GuiObject in collection do
			local uiScale: UIScale? = element:FindFirstChild("UIScale") :: UIScale
			if not uiScale then
				local newUiScale: UIScale = Instance.new("UIScale")
				newUiScale.Scale = 1
				newUiScale.Parent = element
				uiScale = newUiScale
			end

			local base: number = originalScalesByElement[element]
			if not base then
				base = (uiScale :: UIScale).Scale
				originalScalesByElement[element] = base
			end

			local target: number = base * scale
			local tween: Tween =
				TweenService:Create(uiScale :: UIScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = target })
			tween:Play()
		end
	end

	local function InputEnded(): ()
		task.defer(Animate, 1)
	end

	local function InputBegan(): ()
		task.spawn(Animate, BUTTON_SIZE_MULTIPLIER)
		SFX.new(SFX.Sounds.InterfacePress, 0.4, false)
	end

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
