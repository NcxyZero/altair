local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local GetBridge = require(ReplicatedStorage.util.Core.GetBridge)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)

export type FriendBoostController = {
	ConnectCoreEvents: (self: FriendBoostController, generation: number) -> (),
	Init: (self: FriendBoostController) -> (),
	RequestRefresh: (self: FriendBoostController, otherPlayer: unknown) -> (),
	connectionGeneration: number,
	index: number,
	type: string,
	path: InitializerTypes.ClientPath,
	maid: Maid.Maid,
}

local FriendBoostController: FriendBoostController = {} :: any
FriendBoostController.connectionGeneration = 0
FriendBoostController.index = 2
FriendBoostController.type = "controller"
FriendBoostController.maid = Maid.new()

local CORE_EVENT_RETRY_INTERVAL: number = 1 -- GetCore keys are registered asynchronously by Roblox CoreScripts
local FRIEND_BOOST_BRIDGE: any = GetBridge("FriendBoost")

function FriendBoostController:ConnectCoreEvents(generation: number): ()
	while self.connectionGeneration == generation do
		local friendedSuccess: boolean, friendedResult: unknown =
			pcall(StarterGui.GetCore, StarterGui, "PlayerFriendedEvent")
		local unfriendedSuccess: boolean, unfriendedResult: unknown =
			pcall(StarterGui.GetCore, StarterGui, "PlayerUnfriendedEvent")
		local friendedEvent: BindableEvent = friendedResult :: any
		local unfriendedEvent: BindableEvent = unfriendedResult :: any
		if
			friendedSuccess
			and unfriendedSuccess
			and typeof(friendedEvent) == "Instance"
			and friendedEvent:IsA("BindableEvent")
			and typeof(unfriendedEvent) == "Instance"
			and unfriendedEvent:IsA("BindableEvent")
		then
			if self.connectionGeneration ~= generation then
				return
			end

			self.maid:GiveTask(friendedEvent.Event:Connect(function(otherPlayer: unknown): ()
				self:RequestRefresh(otherPlayer)
			end))

			self.maid:GiveTask(unfriendedEvent.Event:Connect(function(otherPlayer: unknown): ()
				self:RequestRefresh(otherPlayer)
			end))

			return
		end

		task.wait(CORE_EVENT_RETRY_INTERVAL)
	end
end

function FriendBoostController:Init(): ()
	self.connectionGeneration += 1
	self.maid:DoCleaning()
	self.maid = Maid.new()

	if not GameConfig.game.friendBoostEnabled then
		return
	end

	task.spawn(self.ConnectCoreEvents, self, self.connectionGeneration)
end

function FriendBoostController:RequestRefresh(otherPlayer: unknown): ()
	local userId: number? = typeof(otherPlayer) == "Instance" and otherPlayer:IsA("Player") and otherPlayer.UserId
		or nil

	FRIEND_BOOST_BRIDGE:Fire({
		userId = userId,
	})
end

return FriendBoostController
