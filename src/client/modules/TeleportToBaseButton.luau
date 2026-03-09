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

local TeleportToBaseButton: Default = {} :: Default
TeleportToBaseButton.__index = TeleportToBaseButton
TeleportToBaseButton.type = "local_tag"
TeleportToBaseButton.tag = script.Name

local TeleportToBaseBridge = GetBridge("TeleportToBase")

function TeleportToBaseButton.new(instance: GuiButton, path: InitializerTypes.ClientPath): Default
	local self = setmetatable({}, TeleportToBaseButton)
	self.instance = instance
	self.path = path
	self.maid = Maid.new()

	self.maid:GiveTask(self.instance.MouseButton1Down:Connect(function(): ()
		TeleportToBaseBridge:Fire()
	end))

	return self
end

function TeleportToBaseButton:Destroy(): ()
	self.maid:DoCleaning()
end

return TeleportToBaseButton
