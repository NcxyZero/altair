local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local ClientData = require(ReplicatedStorage.client.modules.ClientData)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Core.Logger)
local Maid = require(ReplicatedStorage.package.Maid)
local ProfileTypes = require(ReplicatedStorage.shared.reflex.ProfileTypes)
local settingsProfile = require(ReplicatedStorage.shared.reflex.settingsProfile)

export type BackgroundMusicController = {
	Init: (self: BackgroundMusicController) -> (),
	PlayNext: (self: BackgroundMusicController) -> (),
	RefreshSounds: (self: BackgroundMusicController) -> (),
	StopCurrent: (self: BackgroundMusicController) -> (),
	UpdateEnabled: (self: BackgroundMusicController, volume: number) -> (),
	sounds: { Sound },
	baseVolume: number,
	currentIndex: number,
	index: number?,
	isEnabled: boolean,
	type: string,
	currentSound: Sound?,
	path: InitializerTypes.ClientPath?,
	soundGroup: SoundGroup?,
	maid: Maid.Maid,
	playbackMaid: Maid.Maid,
}

local BackgroundMusicController: BackgroundMusicController = {
	sounds = {},
	baseVolume = 0,
	currentIndex = 0,
	isEnabled = false,
	type = "controller",
	maid = Maid.new(),
	playbackMaid = Maid.new(),
} :: any

local BASE_VOLUME_ATTRIBUTE: string = "BaseVolume" -- authored SoundGroup volume, recorded the first time the controller starts
local DEFAULT_MUSIC_VOLUME: number = settingsProfile.DEFAULT_STATE.musicVolume -- settingsProfile default of musicVolume
local MAXIMUM_GROUP_VOLUME: number = 10 -- highest SoundGroup volume Roblox accepts
local MUSIC_ON_VOLUME: number = DEFAULT_MUSIC_VOLUME > 0 and DEFAULT_MUSIC_VOLUME or 1 -- musicVolume that plays the authored volume; SettingsUI stores it when GameMusic is switched on
local SOUND_GROUP_NAME: string = "BackgroundMusic" -- included in default.config.json
local MUSIC_SETTING_KEY: string = "musicVolume"

function BackgroundMusicController:RefreshSounds(): ()
	local soundGroup: SoundGroup? = self.soundGroup
	if not soundGroup then
		self.sounds = {}
		self.currentIndex = 0

		return
	end

	local children: { Instance } = soundGroup:GetChildren()
	local sounds: { Sound } = {}

	for index: number = 1, #children do
		local child: Instance = children[index]
		if child:IsA("Sound") then
			local sound: Sound = child
			sound.SoundGroup = soundGroup
			sound.Looped = false

			table.insert(sounds, sound)
		end
	end

	self.sounds = sounds

	if self.currentIndex > #sounds then
		self.currentIndex = 0
	end
end

function BackgroundMusicController:StopCurrent(): ()
	self.playbackMaid:DoCleaning()

	local currentSound: Sound? = self.currentSound
	if not currentSound then
		return
	end

	currentSound:Stop()
	self.currentSound = nil
end

function BackgroundMusicController:PlayNext(): ()
	if not self.isEnabled then
		return
	end

	local sounds: { Sound } = self.sounds
	if #sounds == 0 then
		return
	end

	self.playbackMaid:DoCleaning()
	self.currentIndex += 1
	if self.currentIndex > #sounds then
		self.currentIndex = 1
	end

	local sound: Sound = sounds[self.currentIndex]
	self.currentSound = sound
	sound.Looped = false
	sound.TimePosition = 0
	sound:Play()

	self.playbackMaid:GiveTask(sound.Ended:Connect(function(): ()
		self:PlayNext()
	end))
end

-- The setting scales the authored group volume, so the default musicVolume plays the music as authored.
function BackgroundMusicController:UpdateEnabled(volume: number): ()
	local soundGroup: SoundGroup? = self.soundGroup
	if soundGroup then
		soundGroup.Volume = math.clamp(self.baseVolume * volume / MUSIC_ON_VOLUME, 0, MAXIMUM_GROUP_VOLUME)
	end

	local enabled: boolean = volume > 0
	if self.isEnabled == enabled then
		return
	end

	self.isEnabled = enabled

	if enabled then
		self:PlayNext()

		return
	end

	self:StopCurrent()
end

function BackgroundMusicController:Init(): ()
	self.maid = Maid.new()
	self.playbackMaid = Maid.new()
	self.maid:GiveTask(self.playbackMaid)
	self.sounds = {}
	self.currentIndex = 0
	self.currentSound = nil
	self.isEnabled = false

	local soundGroupInstance: Instance? = SoundService:FindFirstChild(SOUND_GROUP_NAME)
	if not soundGroupInstance or not soundGroupInstance:IsA("SoundGroup") then
		Logger.warn(`BackgroundMusicController: SoundGroup {SOUND_GROUP_NAME} not found in SoundService`)

		return
	end

	local soundGroup: SoundGroup = soundGroupInstance
	self.soundGroup = soundGroup

	local recordedVolume: unknown = soundGroup:GetAttribute(BASE_VOLUME_ATTRIBUTE)
	self.baseVolume = type(recordedVolume) == "number" and math.max(recordedVolume, 0) or soundGroup.Volume

	soundGroup:SetAttribute(BASE_VOLUME_ATTRIBUTE, self.baseVolume)

	self:RefreshSounds()

	self.maid:GiveTask(soundGroup.ChildAdded:Connect(function(child: Instance): ()
		if not child:IsA("Sound") then
			return
		end

		self:RefreshSounds()

		if self.isEnabled and not self.currentSound then
			self:PlayNext()
		end
	end))

	self.maid:GiveTask(soundGroup.ChildRemoved:Connect(function(child: Instance): ()
		if not child:IsA("Sound") then
			return
		end

		if self.currentSound == child then
			self.currentSound = nil
		end

		self:RefreshSounds()

		if self.isEnabled and not self.currentSound then
			self:PlayNext()
		end
	end))

	local producer: ProfileTypes.PlayerProducer = ClientData:GetPlayerProducerAsync():expect()
	local currentValueAny: any = producer:getState().settings[MUSIC_SETTING_KEY]
	local currentValue: number = type(currentValueAny) == "number" and currentValueAny or 0

	self:UpdateEnabled(currentValue)

	self.maid:GiveTask(producer:subscribe(function(state): any
		return state.settings[MUSIC_SETTING_KEY]
	end, function(nextValueAny: any): ()
		local nextValue: number = type(nextValueAny) == "number" and nextValueAny or 0

		self:UpdateEnabled(nextValue)
	end))
end

return BackgroundMusicController
