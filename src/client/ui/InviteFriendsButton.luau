local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local CanSendGameInvite = require(ReplicatedStorage.util.CanSendGameInvite)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local LocalPlayer = require(ReplicatedStorage.util.LocalPlayer)
local Maid = require(ReplicatedStorage.package.Maid)

export type InviteFriendsButton = {
	__index: InviteFriendsButton,
	path: InitializerTypes.ClientPath,
	tag: string,
	type: string,
	instance: GuiButton,
	maid: Maid.Maid,
	new: (instance: GuiButton, path: InitializerTypes.ClientPath) -> InviteFriendsButton,
	Destroy: (self: InviteFriendsButton) -> (),
	PromptGameInvite: (self: InviteFriendsButton) -> (),
}

local InviteFriendsButton: InviteFriendsButton = {} :: InviteFriendsButton
InviteFriendsButton.__index = InviteFriendsButton
InviteFriendsButton.type = "local_tag"
InviteFriendsButton.tag = script.Name

function InviteFriendsButton.new(instance: GuiButton, path: InitializerTypes.ClientPath): InviteFriendsButton
	local self = setmetatable({}, InviteFriendsButton)
	self.instance = instance
	self.path = path
	self.maid = Maid.new()

	self.maid:GiveTask(instance.MouseButton1Down:Connect(function(): ()
		self:PromptGameInvite()
	end))

	return self
end

function InviteFriendsButton:PromptGameInvite(): ()
	if not CanSendGameInvite(LocalPlayer) then
		return
	end

	SocialService:PromptGameInvite(LocalPlayer)
end

function InviteFriendsButton:Destroy(): ()
	self.maid:DoCleaning()
end

return InviteFriendsButton
