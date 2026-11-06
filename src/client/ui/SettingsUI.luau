local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ClickRipple = require(ReplicatedStorage.util.Effects.ClickRipple)
local ClientData = require(ReplicatedStorage.client.modules.ClientData)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Core.Logger)
local Maid = require(ReplicatedStorage.package.Maid)
local OpenGui = require(ReplicatedStorage.util.Core.OpenGui)
local ProfileTypes = require(ReplicatedStorage.shared.reflex.ProfileTypes)
local SFX = require(ReplicatedStorage.util.Core.SFX)
local TopbarPlus = require(ReplicatedStorage.package.topbarplus)
local settingsProfile = require(ReplicatedStorage.shared.reflex.settingsProfile)

type IconConnection = {
	Disconnect: (self: IconConnection) -> (),
}

type IconSelectionSignal = {
	Connect: (self: IconSelectionSignal, callback: (...any) -> ()) -> IconConnection,
}

-- TopbarPlus 3.4.0 omits these runtime members from its exported Icon type.
type TopbarIcon = TopbarPlus.Icon & {
	deselected: IconSelectionSignal,
	isSelected: boolean,
	selected: IconSelectionSignal,
}

type ToggleConfig = {
	actionName: string,
	frameName: string,
	stateKey: string,
	enabledValue: number?,
}

type VisualState = {
	displayDistanceType: Enum.HumanoidDisplayDistanceType?,
	enabled: boolean?,
	localTransparencyModifier: number?,
}

export type SettingsUI = {
	ApplyCharacterHidden: (self: SettingsUI, character: Model, hidden: boolean) -> (),
	ApplyHiddenVisual: (self: SettingsUI, instance: Instance, hidden: boolean) -> (),
	ApplyMapDetail: (self: SettingsUI, instance: Instance, enabled: boolean) -> (),
	ApplySetting: (self: SettingsUI, stateKey: string, value: unknown) -> (),
	BindOtherCharacter: (self: SettingsUI, player: Player, character: Model) -> (),
	BindOtherPlayer: (self: SettingsUI, player: Player) -> (),
	BindPlayerProducer: (self: SettingsUI, producer: ProfileTypes.PlayerProducer) -> (),
	Destroy: (self: SettingsUI) -> (),
	RenderToggle: (self: SettingsUI, button: GuiButton, enabled: boolean) -> (),
	SetHideOtherPlayers: (self: SettingsUI, enabled: boolean) -> (),
	SetMapDetailsEnabled: (self: SettingsUI, enabled: boolean) -> (),
	SetupTopbarIcon: (self: SettingsUI) -> (),
	SetupWorldSettings: (self: SettingsUI) -> (),
	TrackMapDetail: (self: SettingsUI, instance: Instance) -> (),
	new: (instance: Frame, path: InitializerTypes.ClientPath) -> SettingsUI?,
	__index: SettingsUI,
	characterMaids: { [Player]: Maid.Maid },
	hiddenVisualStates: { [Instance]: VisualState },
	mapDetailStates: { [Instance]: VisualState },
	playerMaids: { [Player]: Maid.Maid },
	settingButtons: { [string]: GuiButton },
	destroyed: boolean,
	hideOtherPlayers: boolean,
	mapDetailsEnabled: boolean,
	originalGlobalShadows: boolean,
	tag: string,
	type: string,
	instance: Frame,
	path: InitializerTypes.ClientPath,
	playerProducer: ProfileTypes.PlayerProducer?,
	maid: Maid.Maid,
	mapDetailMaid: Maid.Maid,
}

local SettingsUI: SettingsUI = {} :: any
SettingsUI.__index = SettingsUI
SettingsUI.tag = script.Name
SettingsUI.type = "local_tag"

local DEFAULT_MUSIC_VOLUME: number = settingsProfile.DEFAULT_STATE.musicVolume -- settingsProfile default of musicVolume
local DEFAULT_SFX_VOLUME: number = settingsProfile.DEFAULT_STATE.sfxVolume -- settingsProfile default of sfxVolume
local MAP_DETAIL_TAG: string = "MapDetail" -- extra instances hidden by the MapDetails toggle
local MUSIC_ON_VOLUME: number = DEFAULT_MUSIC_VOLUME > 0 and DEFAULT_MUSIC_VOLUME or 1 -- musicVolume stored when GameMusic is switched on
local SETTINGS_ICON_IMAGE: string = "rbxassetid://6031280882" -- topbar icon image
local SFX_ON_VOLUME: number = DEFAULT_SFX_VOLUME > 0 and DEFAULT_SFX_VOLUME or 1 -- sfxVolume stored when SoundEffects is switched on
local STATE_TEXT_NAME: string = "StateText" -- On/Off label inside each toggle button

-- ScrollingFrame.<frameName>.Button toggles settings.<stateKey> through the producer action <actionName>
local TOGGLES: { ToggleConfig } = {
	{
		actionName = "setMusicVolume",
		enabledValue = MUSIC_ON_VOLUME,
		frameName = "GameMusic",
		stateKey = "musicVolume",
	},
	{
		actionName = "setSFXVolume",
		enabledValue = SFX_ON_VOLUME,
		frameName = "SoundEffects",
		stateKey = "sfxVolume",
	},
	{
		actionName = "setClickRippleEnabled",
		frameName = "ClickEffect",
		stateKey = "clickRippleEnabled",
	},
	{
		actionName = "setShadowsEnabled",
		frameName = "Shadows",
		stateKey = "shadowsEnabled",
	},
	{
		actionName = "setMapDetailsEnabled",
		frameName = "MapDetails",
		stateKey = "mapDetailsEnabled",
	},
	{
		actionName = "setHideOtherPlayers",
		frameName = "HideOtherPlayers",
		stateKey = "hideOtherPlayers",
	},
}

local function isEnabledValue(value: unknown): boolean
	if type(value) == "number" then
		return value > 0
	end

	return value == true
end

local function isEnabledVisual(instance: Instance): boolean
	return instance:IsA("Beam")
		or instance:IsA("Fire")
		or instance:IsA("Highlight")
		or instance:IsA("Light")
		or instance:IsA("ParticleEmitter")
		or instance:IsA("Smoke")
		or instance:IsA("Sparkles")
		or instance:IsA("Trail")
end

local function isAutomaticMapDetail(instance: Instance, map: Instance): boolean
	if not instance:IsDescendantOf(map) then
		return false
	end

	return instance:IsA("Decal") or instance:IsA("Texture") or isEnabledVisual(instance)
end

-- BaseParts and Decals (Textures inherit from Decal) hide locally without touching their authored Transparency.
local function usesTransparencyModifier(instance: Instance): boolean
	return instance:IsA("BasePart") or instance:IsA("Decal")
end

local function restoreVisual(instance: Instance, state: VisualState): ()
	if state.localTransparencyModifier ~= nil and usesTransparencyModifier(instance) then
		(instance :: any).LocalTransparencyModifier = state.localTransparencyModifier
	elseif state.enabled ~= nil and (isEnabledVisual(instance) or instance:IsA("LayerCollector")) then
		(instance :: any).Enabled = state.enabled
	elseif state.displayDistanceType ~= nil and instance:IsA("Humanoid") then
		instance.DisplayDistanceType = state.displayDistanceType
	end
end

function SettingsUI:ApplyHiddenVisual(instance: Instance, hidden: boolean): ()
	local existingState: VisualState? = self.hiddenVisualStates[instance]
	if not hidden then
		if not existingState or not instance.Parent then
			self.hiddenVisualStates[instance] = nil

			return
		end

		restoreVisual(instance, existingState)

		self.hiddenVisualStates[instance] = nil

		return
	end

	if usesTransparencyModifier(instance) then
		if not existingState then
			existingState = {
				localTransparencyModifier = (instance :: any).LocalTransparencyModifier,
			}
			self.hiddenVisualStates[instance] = existingState
		end

		(instance :: any).LocalTransparencyModifier = 1
	elseif isEnabledVisual(instance) or instance:IsA("BillboardGui") or instance:IsA("SurfaceGui") then
		if not existingState then
			existingState = {
				enabled = (instance :: any).Enabled,
			}
			self.hiddenVisualStates[instance] = existingState
		end

		(instance :: any).Enabled = false
	elseif instance:IsA("Humanoid") then
		-- The default name and health display would float above the hidden character.
		if not existingState then
			existingState = {
				displayDistanceType = instance.DisplayDistanceType,
			}
			self.hiddenVisualStates[instance] = existingState
		end

		instance.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

function SettingsUI:ApplyCharacterHidden(character: Model, hidden: boolean): ()
	local descendants: { Instance } = character:GetDescendants()
	for index: number = 1, #descendants do
		self:ApplyHiddenVisual(descendants[index], hidden)
	end
end

-- Hiding records the state the detail had at that moment; enabling restores it and forgets the detail.
function SettingsUI:ApplyMapDetail(instance: Instance, enabled: boolean): ()
	local existingState: VisualState? = self.mapDetailStates[instance]
	if enabled then
		self.mapDetailMaid[instance] = nil
		self.mapDetailStates[instance] = nil

		if existingState then
			restoreVisual(instance, existingState)
		end

		return
	end

	if usesTransparencyModifier(instance) then
		if not existingState then
			existingState = {
				localTransparencyModifier = (instance :: any).LocalTransparencyModifier,
			}
			self.mapDetailStates[instance] = existingState
		end

		(instance :: any).LocalTransparencyModifier = 1
	elseif isEnabledVisual(instance) then
		if not existingState then
			local effect: any = instance
			local newState: VisualState = {
				enabled = effect.Enabled,
			}
			self.mapDetailStates[instance] = newState

			-- An effect that game code turns on while details are off stays off and comes back with the details.
			self.mapDetailMaid[instance] = effect:GetPropertyChangedSignal("Enabled"):Connect(function(): ()
				if not effect.Enabled then
					return
				end

				newState.enabled = true

				effect.Enabled = false
			end)
		end

		(instance :: any).Enabled = false
	end
end

-- Only details in Workspace are hidden, so a tagged template elsewhere keeps its state for the clones made from it.
function SettingsUI:TrackMapDetail(instance: Instance): ()
	if self.mapDetailsEnabled or not instance:IsDescendantOf(Workspace) then
		return
	end

	if instance:HasTag(MAP_DETAIL_TAG) then
		self:ApplyMapDetail(instance, false)

		local descendants: { Instance } = instance:GetDescendants()
		for index: number = 1, #descendants do
			self:ApplyMapDetail(descendants[index], false)
		end

		return
	end

	local map: Instance? = Workspace:FindFirstChild("Map")
	if map and isAutomaticMapDetail(instance, map) then
		self:ApplyMapDetail(instance, false)
	end
end

-- Map details are only tracked while they are switched off, so nothing is recorded while they show.
function SettingsUI:SetMapDetailsEnabled(enabled: boolean): ()
	if self.mapDetailsEnabled == enabled then
		return
	end

	self.mapDetailsEnabled = enabled

	self.mapDetailMaid:DoCleaning()

	if enabled then
		for instance: Instance, state: VisualState in self.mapDetailStates do
			restoreVisual(instance, state)
		end

		table.clear(self.mapDetailStates)

		return
	end

	local map: Instance? = Workspace:FindFirstChild("Map")
	if map then
		local descendants: { Instance } = map:GetDescendants()
		for index: number = 1, #descendants do
			self:TrackMapDetail(descendants[index])
		end
	end

	local taggedDetails: { Instance } = CollectionService:GetTagged(MAP_DETAIL_TAG)
	for index: number = 1, #taggedDetails do
		self:TrackMapDetail(taggedDetails[index])
	end

	self.mapDetailMaid:GiveTask(Workspace.DescendantAdded:Connect(function(descendant: Instance): ()
		self:TrackMapDetail(descendant)
	end))

	self.mapDetailMaid:GiveTask(
		CollectionService:GetInstanceAddedSignal(MAP_DETAIL_TAG):Connect(function(instance: Instance): ()
			self:TrackMapDetail(instance)
		end)
	)

	-- A detail that leaves Workspace (streamed out or destroyed) gets its state back and is forgotten.
	self.mapDetailMaid:GiveTask(Workspace.DescendantRemoving:Connect(function(descendant: Instance): ()
		if self.mapDetailStates[descendant] then
			self:ApplyMapDetail(descendant, true)
		end
	end))
end

function SettingsUI:BindOtherCharacter(player: Player, character: Model): ()
	local oldMaid: Maid.Maid? = self.characterMaids[player]
	if oldMaid then
		oldMaid:DoCleaning()
	end

	local characterMaid: Maid.Maid = Maid.new()
	self.characterMaids[player] = characterMaid

	if self.hideOtherPlayers then
		self:ApplyCharacterHidden(character, true)
	end

	characterMaid:GiveTask(character.DescendantAdded:Connect(function(descendant: Instance): ()
		if self.hideOtherPlayers then
			self:ApplyHiddenVisual(descendant, true)
		end
	end))
end

function SettingsUI:BindOtherPlayer(player: Player): ()
	if player == Players.LocalPlayer or self.playerMaids[player] then
		return
	end

	local playerMaid: Maid.Maid = Maid.new()
	self.playerMaids[player] = playerMaid

	playerMaid:GiveTask(player.CharacterAdded:Connect(function(character: Model): ()
		self:BindOtherCharacter(player, character)
	end))

	playerMaid:GiveTask(player.CharacterRemoving:Connect(function(character: Model): ()
		self:ApplyCharacterHidden(character, false)

		local characterMaid: Maid.Maid? = self.characterMaids[player]
		if characterMaid then
			characterMaid:DoCleaning()

			self.characterMaids[player] = nil
		end
	end))

	local character: Model? = player.Character
	if character then
		self:BindOtherCharacter(player, character)
	end
end

function SettingsUI:SetHideOtherPlayers(enabled: boolean): ()
	self.hideOtherPlayers = enabled

	local players: { Player } = Players:GetPlayers()
	for index: number = 1, #players do
		local player: Player = players[index]
		if player == Players.LocalPlayer then
			continue
		end

		local character: Model? = player.Character
		if character then
			self:ApplyCharacterHidden(character, enabled)
		end
	end

	if enabled then
		return
	end

	for instance: Instance, state: VisualState in self.hiddenVisualStates do
		if instance.Parent then
			restoreVisual(instance, state)
		end

		self.hiddenVisualStates[instance] = nil
	end
end

function SettingsUI:ApplySetting(stateKey: string, value: unknown): ()
	local enabled: boolean = isEnabledValue(value)
	if stateKey == "sfxVolume" then
		local volume: number = type(value) == "number" and value or 0

		SFX.SetVolume(volume)
	elseif stateKey == "clickRippleEnabled" then
		if enabled then
			ClickRipple:Enable()
		else
			ClickRipple:Disable()
		end
	elseif stateKey == "shadowsEnabled" then
		Lighting.GlobalShadows = enabled
	elseif stateKey == "mapDetailsEnabled" then
		self:SetMapDetailsEnabled(enabled)
	elseif stateKey == "hideOtherPlayers" then
		self:SetHideOtherPlayers(enabled)
	end
end

function SettingsUI:RenderToggle(button: GuiButton, enabled: boolean): ()
	local onGradient: UIGradient? = button:FindFirstChild("On") :: any
	if onGradient and onGradient:IsA("UIGradient") then
		onGradient.Enabled = enabled
	end

	local offGradient: UIGradient? = button:FindFirstChild("Off") :: any
	if offGradient and offGradient:IsA("UIGradient") then
		offGradient.Enabled = not enabled
	end

	local text: string = enabled and "On" or "Off"
	local descendants: { Instance } = button:GetDescendants()
	for index: number = 1, #descendants do
		local descendant: Instance = descendants[index]
		if descendant:IsA("TextLabel") and descendant.Name == STATE_TEXT_NAME then
			descendant.Text = text
		end
	end
end

function SettingsUI:BindPlayerProducer(producer: ProfileTypes.PlayerProducer): ()
	self.playerProducer = producer

	local scrollingFrame: ScrollingFrame = self.instance:FindFirstChild("ScrollingFrame") :: any
	if not scrollingFrame or not scrollingFrame:IsA("ScrollingFrame") then
		Logger.warn("SettingsUI is missing ScrollingFrame")

		return
	end

	for index: number = 1, #TOGGLES do
		local config: ToggleConfig = TOGGLES[index]
		local settingFrame: Frame = scrollingFrame:FindFirstChild(config.frameName) :: any
		local button: GuiButton = settingFrame and settingFrame:FindFirstChild("Button") :: any
		if not settingFrame or not settingFrame:IsA("Frame") or not button or not button:IsA("GuiButton") then
			Logger.warn(`SettingsUI is missing {config.frameName}.Button`)

			continue
		end

		self.settingButtons[config.stateKey] = button

		self.maid:GiveTask(button.MouseButton1Down:Connect(function(): ()
			local state: ProfileTypes.PlayerState = producer:getState()
			local currentValue: unknown = (state.settings :: any)[config.stateKey]
			local nextEnabled: boolean = not isEnabledValue(currentValue)
			local nextValue: unknown = config.enabledValue and (nextEnabled and config.enabledValue or 0) or nextEnabled
			local action: any = (producer :: any)[config.actionName]
			if type(action) ~= "function" then
				Logger.warn(`SettingsUI producer action {config.actionName} is unavailable`)

				return
			end

			action(nextValue)
		end))

		local initialValue: unknown = (producer:getState().settings :: any)[config.stateKey]

		self:RenderToggle(button, isEnabledValue(initialValue))
		self:ApplySetting(config.stateKey, initialValue)

		self.maid:GiveTask(producer:subscribe(function(state: any): unknown
			return state.settings[config.stateKey]
		end, function(nextValue: unknown): ()
			self:RenderToggle(button, isEnabledValue(nextValue))
			self:ApplySetting(config.stateKey, nextValue)
		end))
	end
end

function SettingsUI:SetupWorldSettings(): ()
	local players: { Player } = Players:GetPlayers()
	for index: number = 1, #players do
		self:BindOtherPlayer(players[index])
	end

	self.maid:GiveTask(Players.PlayerAdded:Connect(function(player: Player): ()
		self:BindOtherPlayer(player)
	end))

	self.maid:GiveTask(Players.PlayerRemoving:Connect(function(player: Player): ()
		local character: Model? = player.Character
		if character then
			self:ApplyCharacterHidden(character, false)
		end

		local characterMaid: Maid.Maid? = self.characterMaids[player]
		if characterMaid then
			characterMaid:DoCleaning()

			self.characterMaids[player] = nil
		end

		local playerMaid: Maid.Maid? = self.playerMaids[player]
		if playerMaid then
			playerMaid:DoCleaning()

			self.playerMaids[player] = nil
		end
	end))

	self.maid:GiveTask(UserInputService.InputBegan:Connect(function(input: InputObject): ()
		local inputType: Enum.UserInputType = input.UserInputType
		if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
			return
		end

		ClickRipple:FireAtPosition(Vector2.new(input.Position.X, input.Position.Y))
	end))
end

function SettingsUI:SetupTopbarIcon(): ()
	local icon: TopbarIcon = TopbarPlus.new() :: TopbarIcon
	icon:align("Left")
	icon:setCaption("Settings")
	icon:setImage(SETTINGS_ICON_IMAGE)
	icon:setName("Settings")

	self.maid:GiveTask(icon.selected:Connect(function(): ()
		if not self.instance.Visible then
			OpenGui:Open(self)
		end
	end))
	self.maid:GiveTask(icon.deselected:Connect(function(): ()
		if self.instance.Visible then
			OpenGui:Close(self)
		end
	end))
	self.maid:GiveTask(self.instance:GetPropertyChangedSignal("Visible"):Connect(function(): ()
		if self.instance.Visible and not icon.isSelected then
			icon:select()
		elseif not self.instance.Visible and icon.isSelected then
			icon:deselect()
		end
	end))
	self.maid:GiveTask(function(): ()
		icon:destroy()
	end)
end

function SettingsUI.new(instance: Frame, path: InitializerTypes.ClientPath): SettingsUI?
	if not instance:IsA("Frame") then
		Logger.warn(`SettingsUI tag requires a Frame, got {instance.ClassName}`)

		return
	end

	local self: SettingsUI = setmetatable({}, SettingsUI) :: any
	self.characterMaids = {}
	self.destroyed = false
	self.hiddenVisualStates = {}
	self.hideOtherPlayers = false
	self.instance = instance
	self.maid = Maid.new()
	self.mapDetailMaid = Maid.new()
	self.mapDetailStates = {}
	self.mapDetailsEnabled = true
	self.originalGlobalShadows = Lighting.GlobalShadows
	self.path = path
	self.playerMaids = {}
	self.settingButtons = {}

	self:SetupWorldSettings()
	OpenGui:Register(self)
	self:SetupTopbarIcon()

	ClientData:GetPlayerProducerAsync():andThen(function(producer: ProfileTypes.PlayerProducer): ()
		if self.destroyed or not self.instance.Parent then
			return
		end

		self:BindPlayerProducer(producer)
	end)

	return self
end

function SettingsUI:Destroy(): ()
	self.destroyed = true

	self:SetHideOtherPlayers(false)
	self:SetMapDetailsEnabled(true)

	Lighting.GlobalShadows = self.originalGlobalShadows

	ClickRipple:Disable()

	for player: Player, characterMaid: Maid.Maid in self.characterMaids do
		characterMaid:DoCleaning()

		self.characterMaids[player] = nil
	end

	for player: Player, playerMaid: Maid.Maid in self.playerMaids do
		playerMaid:DoCleaning()

		self.playerMaids[player] = nil
	end

	self.maid:DoCleaning()
end

return SettingsUI
