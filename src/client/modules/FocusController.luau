local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local ClientData = require(StarterPlayer.StarterPlayerScripts.modules.ClientData)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local LocalPlayer = require(ReplicatedStorage.util.LocalPlayer)
local gameProfile = require(ReplicatedStorage.shared.reflex.gameProfile)

export type Default = {
	index: number?,
	type: string?,
	path: InitializerTypes.ClientPath,
	Init: (self: Default) -> (),
}

local FocusController: Default = {} :: Default
FocusController.type = "controller"

function FocusController:Init(): ()
	ClientData.gameProducer:subscribe(function(state: gameProfile.State)
		return state.focus
	end, function(focus: Player?)
		local humanoid: Humanoid = (focus and focus.Character)
			and focus.Character:FindFirstChild("Humanoid") :: Humanoid
		local currectCamera: Camera = workspace.CurrentCamera
		currectCamera.CameraSubject = (focus and humanoid) and humanoid or LocalPlayer.Character.Humanoid
	end)
end

return FocusController
