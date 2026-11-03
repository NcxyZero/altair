local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local GetBridge = require(ReplicatedStorage.util.Core.GetBridge)
local Maid = require(ReplicatedStorage.package.Maid)
local NotificationUI = require(ReplicatedStorage.client.ui.NotificationUI)

local LocalPlayer: Player = Players.LocalPlayer

export type AntiKickController = {
	HandleIdled: (self: AntiKickController, timeIdle: number) -> (),
	Init: (self: AntiKickController) -> (),
	lastRequestAt: number,
	type: string,
	maid: Maid.Maid,
}

local AntiKickController: AntiKickController = {
	lastRequestAt = -math.huge,
	type = "controller",
	maid = Maid.new(),
} :: any

local CONFIG = GameConfig.game.antiKick
local REJOIN_BRIDGE: any = GetBridge("AntiIdleRejoin")

function AntiKickController:HandleIdled(timeIdle: number): ()
	-- A reserved server only takes players with its access code, so the server never rejoins anyone there.
	if
		not CONFIG.enabled
		or timeIdle < CONFIG.idleSeconds
		or (game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0)
	then
		return
	end

	local now: number = os.clock()
	if now - self.lastRequestAt < CONFIG.retrySeconds then
		return
	end

	local character: Model? = LocalPlayer.Character
	local root: BasePart = character and character:FindFirstChild("HumanoidRootPart") :: any
	if not root then
		return
	end

	self.lastRequestAt = now

	NotificationUI.Send({ text = "Rejoining to prevent idle kick...", seconds = 5 })
	REJOIN_BRIDGE:Fire()
end

function AntiKickController:Init(): ()
	self.maid:DoCleaning()
	self.lastRequestAt = -math.huge

	if not CONFIG.enabled then
		return
	end

	self.maid:GiveTask(LocalPlayer.Idled:Connect(function(timeIdle: number): ()
		self:HandleIdled(timeIdle)
	end))
end

return AntiKickController
