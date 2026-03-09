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

local OpenGuiButton: Default = {} :: any
OpenGuiButton.__index = OpenGuiButton
OpenGuiButton.type = "local_tag"
OpenGuiButton.tag = script.Name

local TARGET_ATTR: string = "TargetTag"
local TARGET_ATTR_ALT: string = "Target"

local function findTargetClass(self: Default): any?
	if not self.requestedTag then
		return
	end

	return TagManager:FindLocalTagClass(self.requestedTag)
end

function OpenGuiButton.new(instance: GuiButton, path: InitializerTypes.ClientPath): Default
	local self = setmetatable({}, OpenGuiButton)
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

			OpenGui:Open(targetClass)
		end))
	end

	return self
end

function OpenGuiButton:Destroy(): ()
	self.maid:DoCleaning()
end

return OpenGuiButton
