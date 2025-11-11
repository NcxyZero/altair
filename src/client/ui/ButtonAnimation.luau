local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Maid = require(ReplicatedStorage.package.Maid)
local SFX = require(ReplicatedStorage.util.SFX)

local BUTTON_SIZE_MULTIPLIER: number = 0.9
local HOVER_SIZE_MULTIPLIER: number = 1.05
local TAG_NAME: string = script.Name

export type ButtonAnimation = {
	type: string,
	tag: string,
	instance: GuiButton,
	maid: Maid.Maid,
	isHovered: boolean,
	isPressed: boolean,

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
	self.isHovered = false
	self.isPressed = false

	local originalScalesByElement: { [GuiObject]: number } = {}
	local activeTweensByElement: { [GuiObject]: Tween } = {}

	local function getElementsToAnimate(): { GuiObject }
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

		return collection
	end

	local function applyCurrentState(): ()
		local desiredScale: number = 1
		desiredScale = self.isPressed and BUTTON_SIZE_MULTIPLIER or desiredScale
		desiredScale = (not self.isPressed and self.isHovered) and HOVER_SIZE_MULTIPLIER or desiredScale

		for _index: number, element: GuiObject in getElementsToAnimate() do
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

			local target: number = base * desiredScale

			local existing: Tween? = activeTweensByElement[element]
			if existing then
				existing:Cancel()
			end

			local tween: Tween =
				TweenService:Create(uiScale :: UIScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = target })
			activeTweensByElement[element] = tween

			tween.Completed:Connect(function(): ()
				if activeTweensByElement[element] == tween then
					activeTweensByElement[element] = nil
				end
			end)

			tween:Play()
		end
	end

	local function onMouseDown(): ()
		self.isPressed = true
		applyCurrentState()
		SFX.new(SFX.Sounds.InterfacePress, 0.4, false)
	end

	local function onMouseUp(): ()
		self.isPressed = false
		applyCurrentState()
	end

	local function onMouseEnter(): ()
		self.isHovered = true
		applyCurrentState()
	end

	local function onMouseLeave(): ()
		self.isHovered = false
		self.isPressed = false
		applyCurrentState()
	end

	self.maid:GiveTask(instance.MouseButton1Down:Connect(onMouseDown))
	self.maid:GiveTask(instance.MouseButton1Up:Connect(onMouseUp))
	self.maid:GiveTask(instance.MouseEnter:Connect(onMouseEnter))
	self.maid:GiveTask(instance.MouseLeave:Connect(onMouseLeave))

	return self
end

function ButtonAnimation:Destroy(): ()
	self.maid:DoCleaning()
end

return ButtonAnimation
