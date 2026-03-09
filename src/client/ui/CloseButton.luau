local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)
local OpenGui = require(ReplicatedStorage.util.OpenGui)
local TagManager = require(ReplicatedStorage.shared.modules.TagManager)

export type Default = {
	instance: GuiButton,
	maid: Maid.Maid,
	path: InitializerTypes.ClientPath,
	requestedTag: string?,
	__index: Default,
	type: string,
	tag: string,
	new: (instance: GuiButton, path: InitializerTypes.ClientPath) -> Default,
	Destroy: (self: Default) -> (),
}

local CloseGuiButton: Default = {} :: any
CloseGuiButton.__index = CloseGuiButton
CloseGuiButton.type = "local_tag"
CloseGuiButton.tag = script.Name

local TARGET_ATTR: string = "TargetTag"
local TARGET_ATTR_ALT: string = "Target"
local BACK_ACTION_NAME: string = "CloseButton_Back"

local GAMEPAD_TYPES: { Enum.UserInputType } = {
	Enum.UserInputType.Gamepad1,
	Enum.UserInputType.Gamepad2,
	Enum.UserInputType.Gamepad3,
	Enum.UserInputType.Gamepad4,
	Enum.UserInputType.Gamepad5,
	Enum.UserInputType.Gamepad6,
	Enum.UserInputType.Gamepad7,
	Enum.UserInputType.Gamepad8,
}

local function isGamepadInput(inputType: Enum.UserInputType): boolean
	for index: number = 1, #GAMEPAD_TYPES do
		if inputType == GAMEPAD_TYPES[index] then
			return true
		end
	end

	return false
end

local function findTargetClass(self: Default): any
	if not self.requestedTag then
		return
	end

	return TagManager:FindLocalTagClass(self.requestedTag)
end

ContextActionService:BindAction(
	BACK_ACTION_NAME,
	function(_name: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult?
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end

		if not isGamepadInput(input.UserInputType) then
			return Enum.ContextActionResult.Pass
		end

		if OpenGui:CloseCurrent() then
			GuiService.SelectedObject = nil
		end

		return Enum.ContextActionResult.Sink
	end,
	false,
	Enum.KeyCode.ButtonB
)

function CloseGuiButton.new(instance: GuiButton, path: InitializerTypes.ClientPath): Default
	local self = setmetatable({}, CloseGuiButton)
	self.instance = instance
	self.path = path
	self.maid = Maid.new()

	instance.Selectable = true

	local attr: any = instance:GetAttribute(TARGET_ATTR)
	if type(attr) ~= "string" then
		attr = instance:GetAttribute(TARGET_ATTR_ALT)
	end
	if type(attr) == "string" then
		self.requestedTag = attr
	end

	if self.requestedTag then
		self.maid:GiveTask(instance.MouseButton1Down:Connect(function(): ()
			local targetClass: any = findTargetClass(self)
			if not targetClass then
				return
			end

			OpenGui:Close(targetClass)
		end))
	end

	return self
end

function CloseGuiButton:Destroy(): ()
	self.maid:DoCleaning()
end

return CloseGuiButton
