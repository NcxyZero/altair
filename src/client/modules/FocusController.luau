local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClientData = require(ReplicatedStorage.client.modules.ClientData)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local LocalPlayer = require(ReplicatedStorage.util.Core.LocalPlayer)
local Maid = require(ReplicatedStorage.package.Maid)
local gameProfile = require(ReplicatedStorage.shared.reflex.gameProfile)

export type FocusController = {
	CharacterAdded: (self: FocusController, character: Model) -> (),
	HideScreenGui: (self: FocusController, instance: Instance) -> (),
	Init: (self: FocusController) -> (),
	RefreshCamera: (self: FocusController) -> (),
	RefreshHUD: (self: FocusController) -> (),
	Render: (self: FocusController, deltaTime: number) -> (),
	RestoreHUD: (self: FocusController) -> (),
	RestoreScreenGui: (self: FocusController, gui: ScreenGui) -> (),
	UpdateScreenGui: (self: FocusController, gui: ScreenGui) -> (),
	hiddenScreenGuis: { [ScreenGui]: boolean },
	path: InitializerTypes.ClientPath,
	index: number,
	isHUDHidden: boolean,
	type: string,
	wasSpectating: boolean,
	globalFocus: Player?,
	guiMaid: Maid.Maid,
	maid: Maid.Maid,
}

local FocusController: FocusController = {} :: any
FocusController.index = 3
FocusController.hiddenScreenGuis = {}
FocusController.isHUDHidden = false
FocusController.type = "controller"
FocusController.wasSpectating = false
FocusController.maid = Maid.new()
FocusController.guiMaid = Maid.new()

local FREECAM_ENABLED_ATTRIBUTE: string = "FreecamEnabled" -- set by freecam commands; HUD and camera wait while true

function FocusController:UpdateScreenGui(gui: ScreenGui): ()
	local commandWindow: GuiObject = gui.Name == "Cmdr" and gui:FindFirstChild("Frame") :: any
	local enabled: boolean = commandWindow and commandWindow:IsA("GuiObject") and commandWindow.Visible or false
	if gui.Enabled ~= enabled then
		gui.Enabled = enabled
	end
end

function FocusController:HideScreenGui(instance: Instance): ()
	if not self.isHUDHidden or not instance:IsA("ScreenGui") or self.hiddenScreenGuis[instance] ~= nil then
		return
	end
	local gui: ScreenGui = instance :: ScreenGui
	self.hiddenScreenGuis[gui] = gui.Enabled

	local guiMaid: Maid.Maid = Maid.new()
	self.guiMaid[gui] = guiMaid
	guiMaid:GiveTask(gui:GetPropertyChangedSignal("Enabled"):Connect(function(): ()
		self:UpdateScreenGui(gui)
	end))
	guiMaid:GiveTask(gui.AncestryChanged:Connect(function(): ()
		if not gui:IsDescendantOf(LocalPlayer.PlayerGui) then
			self:RestoreScreenGui(gui)
		end
	end))

	local commandWindow: GuiObject = gui.Name == "Cmdr" and gui:FindFirstChild("Frame") :: any
	if commandWindow and commandWindow:IsA("GuiObject") then
		guiMaid:GiveTask(commandWindow:GetPropertyChangedSignal("Visible"):Connect(function(): ()
			self:UpdateScreenGui(gui)
		end))
	end

	self:UpdateScreenGui(gui)
end

function FocusController:RestoreScreenGui(gui: ScreenGui): ()
	local enabled: boolean? = self.hiddenScreenGuis[gui]
	if enabled == nil then
		return
	end
	self.hiddenScreenGuis[gui] = nil
	self.guiMaid[gui] = nil
	gui.Enabled = enabled
end

function FocusController:RestoreHUD(): ()
	self.guiMaid:DoCleaning()
	self.isHUDHidden = false
	for gui: ScreenGui, enabled: boolean in self.hiddenScreenGuis do
		if gui.Parent then
			gui.Enabled = enabled
		end
	end
	self.hiddenScreenGuis = {}
end

function FocusController:RefreshHUD(): ()
	-- The free camera hides and restores the HUD itself; spectating applies its HUD after it.
	if LocalPlayer:GetAttribute(FREECAM_ENABLED_ATTRIBUTE) == true then
		return
	end

	local userId: unknown = LocalPlayer:GetAttribute("SpectateUserId")
	local hideHUD: boolean = type(userId) == "number"
		and userId ~= 0
		and LocalPlayer:GetAttribute("SpectateKeepHUD") ~= true
	if hideHUD == self.isHUDHidden then
		return
	end
	if not hideHUD then
		self:RestoreHUD()

		return
	end
	self.isHUDHidden = true
	self.guiMaid:GiveTask(LocalPlayer.PlayerGui.DescendantAdded:Connect(function(instance: Instance): ()
		self:HideScreenGui(instance)
	end))
	for _index: number, instance: Instance in LocalPlayer.PlayerGui:GetDescendants() do
		self:HideScreenGui(instance)
	end
end

function FocusController:RefreshCamera(): ()
	-- The free camera drives the camera itself, so the focus is applied again once it stops.
	if LocalPlayer:GetAttribute(FREECAM_ENABLED_ATTRIBUTE) == true then
		return
	end

	local userId: unknown = LocalPlayer:GetAttribute("SpectateUserId")
	local spectating: boolean = type(userId) == "number" and userId ~= 0
	local target: Player? = spectating and Players:GetPlayerByUserId(userId :: number)
		or self.globalFocus
		or LocalPlayer
	local character: Model? = target and target.Character
	local humanoid: Humanoid = character and character:FindFirstChildWhichIsA("Humanoid") :: any
	if not humanoid and not spectating then
		local localCharacter: Model? = LocalPlayer.Character
		humanoid = localCharacter and localCharacter:FindFirstChildWhichIsA("Humanoid") :: any
	end

	local camera: Camera = Workspace.CurrentCamera :: any
	if not camera or not humanoid then
		return
	end

	if spectating or self.wasSpectating then
		camera.CameraType = Enum.CameraType.Custom
	end
	if camera.CameraSubject ~= humanoid then
		camera.CameraSubject = humanoid
	end
	self.wasSpectating = spectating
end

function FocusController:CharacterAdded(_character: Model): ()
	self:RefreshCamera()
end

function FocusController:Render(_deltaTime: number): ()
	if LocalPlayer:GetAttribute("SpectateUserId") ~= nil or self.wasSpectating then
		self:RefreshCamera()
	end
end

function FocusController:Init(): ()
	self.maid:DoCleaning()
	self:RestoreHUD()
	self.maid:GiveTask(function(): ()
		self:RestoreHUD()
	end)
	local producer: any = ClientData:GetGameProducerAsync():expect()
	self.globalFocus = producer:getState().focus

	self.maid:GiveTask(producer:subscribe(function(state: gameProfile.State): Player?
		return state.focus
	end, function(focus: Player?): ()
		self.globalFocus = focus

		self:RefreshCamera()
	end))
	self.maid:GiveTask(LocalPlayer:GetAttributeChangedSignal("SpectateUserId"):Connect(function(): ()
		self:RefreshHUD()
		self:RefreshCamera()
	end))
	self.maid:GiveTask(LocalPlayer:GetAttributeChangedSignal("SpectateKeepHUD"):Connect(function(): ()
		self:RefreshHUD()
	end))
	self.maid:GiveTask(LocalPlayer:GetAttributeChangedSignal(FREECAM_ENABLED_ATTRIBUTE):Connect(function(): ()
		-- The free camera stops one signal later and then restores the HUD, so the HUD refresh waits a frame.
		task.delay(0, self.RefreshHUD, self)
		task.defer(self.RefreshCamera, self)
	end))
	self.maid:GiveTask(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function(): ()
		self:RefreshCamera()
	end))

	self:RefreshHUD()
	self:RefreshCamera()
end

return FocusController
