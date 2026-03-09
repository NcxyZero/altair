local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)

export type FloatActionTarget = {
	animationTime: number,
	currentTween: Tween?,
	hidePosition: UDim2,
	showPosition: UDim2,
	target: GuiObject,
}

export type FloatActionUI = {
	animationTime: number,
	instance: GuiButton,
	maid: Maid.Maid,
	path: InitializerTypes.ClientPath,
	tag: string,
	targets: { FloatActionTarget },
	type: string,
	__index: FloatActionUI,
	new: (instance: GuiButton, path: InitializerTypes.ClientPath) -> FloatActionUI?,
	TweenTo: (self: FloatActionUI, targetEntry: FloatActionTarget, position: UDim2) -> (),
	Show: (self: FloatActionUI) -> (),
	Hide: (self: FloatActionUI) -> (),
	Destroy: (self: FloatActionUI) -> (),
}

local DEFAULT_ANIMATION_TIME: number = 0.35
local DEFAULT_FLOAT_OFFSET: number = 12
local DEFAULT_TARGET_NAME: string = "Target"

local FloatActionUI: FloatActionUI = {} :: any
FloatActionUI.__index = FloatActionUI
FloatActionUI.type = "local_tag"
FloatActionUI.tag = script.Name

local function createOffset(basePosition: UDim2, offsetY: number): UDim2
	return UDim2.new(basePosition.X.Scale, basePosition.X.Offset, basePosition.Y.Scale, basePosition.Y.Offset + offsetY)
end

local function targetExists(collection: { GuiObject }, target: GuiObject): boolean
	for _index: number, existing: GuiObject in collection do
		if existing == target then
			return true
		end
	end

	return false
end

local function resolveTargets(instance: GuiObject): { GuiObject }
	local targetNameAttr: string? = instance:GetAttribute("TargetName") :: string?
	local targetName: string = targetNameAttr or DEFAULT_TARGET_NAME

	local targets: { GuiObject } = {}

	for _index: number, child: Instance in instance:GetChildren() do
		if child:IsA("ObjectValue") and child.Value and child.Value:IsA("GuiObject") then
			local value: GuiObject = child.Value :: GuiObject
			if (child.Name == targetName or targetNameAttr == nil) and not targetExists(targets, value) then
				table.insert(targets, value)
			end
		end
	end

	if #targets == 0 then
		for _index: number, child: Instance in instance:GetChildren() do
			if child:IsA("ObjectValue") and child.Value and child.Value:IsA("GuiObject") then
				local value: GuiObject = child.Value :: GuiObject
				if not targetExists(targets, value) then
					table.insert(targets, value)
				end
			end
		end
	end

	if #targets == 0 then
		local targetChild: Instance? = instance:FindFirstChild(targetName)
		if targetChild and targetChild:IsA("GuiObject") and not targetExists(targets, targetChild :: GuiObject) then
			table.insert(targets, targetChild :: GuiObject)
		end
	end

	if #targets == 0 then
		local parent: Instance? = instance.Parent
		if parent then
			local sibling: Instance? = parent:FindFirstChild(targetName)
			if sibling and sibling:IsA("GuiObject") and not targetExists(targets, sibling :: GuiObject) then
				table.insert(targets, sibling :: GuiObject)
			end
		end
	end

	return targets
end

function FloatActionUI.new(instance: GuiButton, path: InitializerTypes.ClientPath): FloatActionUI?
	local targets: { GuiObject } = resolveTargets(instance)
	if #targets == 0 then
		return
	end

	local baseAnimationTime: number = (instance:GetAttribute("AnimationTime") :: number) or DEFAULT_ANIMATION_TIME

	local self = setmetatable({}, FloatActionUI)
	self.instance = instance
	self.path = path
	self.maid = Maid.new()
	self.animationTime = baseAnimationTime
	self.targets = {}

	for _index: number, target: GuiObject in targets do
		local minPosition: UDim2? = target:GetAttribute("Min") :: any
		local maxPosition: UDim2? = target:GetAttribute("Max") :: any
		local basePosition: UDim2 = minPosition or maxPosition or target.Position
		local hidePosition: UDim2 = minPosition or basePosition
		local showPosition: UDim2 = maxPosition or createOffset(basePosition, -DEFAULT_FLOAT_OFFSET)

		if not minPosition and maxPosition then
			hidePosition = createOffset(basePosition, DEFAULT_FLOAT_OFFSET)
		end

		local targetAnimationTime: number = (target:GetAttribute("AnimationTime") :: number) or baseAnimationTime

		local targetEntry: FloatActionTarget = {
			animationTime = targetAnimationTime,
			currentTween = nil,
			hidePosition = hidePosition,
			showPosition = showPosition,
			target = target,
		}

		target.Position = targetEntry.hidePosition

		table.insert(self.targets, targetEntry)
	end

	self.maid:GiveTask(instance.MouseEnter:Connect(function(): ()
		self:Show()
	end))

	self.maid:GiveTask(instance.MouseLeave:Connect(function(): ()
		self:Hide()
	end))

	return self
end

function FloatActionUI:TweenTo(targetEntry: FloatActionTarget, position: UDim2): ()
	if targetEntry.currentTween then
		targetEntry.currentTween:Cancel()
		targetEntry.currentTween = nil
	end

	local tweenInfo: TweenInfo =
		TweenInfo.new(targetEntry.animationTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tween: Tween = TweenService:Create(targetEntry.target, tweenInfo, { Position = position })
	targetEntry.currentTween = tween

	tween.Completed:Connect(function(): ()
		if targetEntry.currentTween == tween then
			targetEntry.currentTween = nil
		end
	end)

	tween:Play()
end

function FloatActionUI:Show(): ()
	for _index: number, targetEntry: FloatActionTarget in self.targets do
		self:TweenTo(targetEntry, targetEntry.showPosition)
	end
end

function FloatActionUI:Hide(): ()
	for _index: number, targetEntry: FloatActionTarget in self.targets do
		self:TweenTo(targetEntry, targetEntry.hidePosition)
	end
end

function FloatActionUI:Destroy(): ()
	for _index: number, targetEntry: FloatActionTarget in self.targets do
		if targetEntry.currentTween then
			targetEntry.currentTween:Cancel()
			targetEntry.currentTween = nil
		end
	end

	self.maid:DoCleaning()
end

return FloatActionUI
