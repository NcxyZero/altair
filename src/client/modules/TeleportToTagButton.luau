local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetBridge = require(ReplicatedStorage.util.GetBridge)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)

export type Default = {
	type: string,
	tag: string,
	path: InitializerTypes.ClientPath,
	instance: GuiButton,
	maid: Maid.Maid,
	__index: Default,
	new: (instance: GuiButton, path: InitializerTypes.ClientPath) -> Default,
	Destroy: (self: Default) -> (),
}

local TeleportToTagButton: Default = {} :: Default
TeleportToTagButton.__index = TeleportToTagButton
TeleportToTagButton.type = "local_tag"
TeleportToTagButton.tag = script.Name

local TeleportToTagBridge = GetBridge("TeleportToTag")

function TeleportToTagButton.new(instance: GuiButton, path: InitializerTypes.ClientPath): Default
	local self = setmetatable({}, TeleportToTagButton)
	self.instance = instance
	self.path = path
	self.maid = Maid.new()

	self.maid:GiveTask(self.instance.MouseButton1Down:Connect(function(): ()
		local tagName: string = self.instance:GetAttribute("TeleportToTagName")
		if type(tagName) == "string" and #tagName > 0 then
			TeleportToTagBridge:Fire(tagName)
		end
	end))

	return self
end

function TeleportToTagButton:Destroy(): ()
	self.maid:DoCleaning()
end

return TeleportToTagButton
