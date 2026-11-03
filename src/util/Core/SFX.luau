local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

export type SFX = {
	Bind: (sound: Sound) -> (),
	new: (
		SoundID: string | { string },
		Volume: number?,
		DoNotOverlaps: boolean?,
		Randomize: boolean?,
		StartTime: number?
	) -> (Sound | { Sound })?,
	SetVolume: (volume: number) -> (),
	Sounds: {
		[string]: string,
	},
}

local SFX: SFX = {} :: SFX

SFX.Sounds = {
	Confetti = "rbxassetid://72685643396992",
	InterfacePress = "rbxassetid://421058925",
	CashButton = "rbxassetid://0",
	NotificationGreat = "rbxassetid://110217765141398",
	ButtonStep = "rbxassetid://139800881181209",
}

local BACKGROUND_MUSIC_NAME: string = "BackgroundMusic" -- SoundGroup driven by the music volume setting instead
local CONTROLLED_SOUND_GROUP_ATTRIBUTE: string = "UseSFXVolume" -- marks SoundGroups that follow the SFX volume setting
local DEFAULT_VOLUME: number = 0.5 -- matches the settingsProfile sfxVolume default
local SOUND_GROUP_NAME: string = "SoundEffectsVolume" -- fallback SoundGroup for sounds that have none
local SOUND_LOAD_TIMEOUT: number = 10 -- seconds a sound may take to load before it is discarded unplayed

local function getSoundGroup(): SoundGroup
	local existing: Instance? = SoundService:FindFirstChild(SOUND_GROUP_NAME)
	if existing and existing:IsA("SoundGroup") then
		existing:SetAttribute(CONTROLLED_SOUND_GROUP_ATTRIBUTE, true)

		return existing
	end

	local soundGroup: SoundGroup = Instance.new("SoundGroup")
	soundGroup.Name = SOUND_GROUP_NAME
	soundGroup.Volume = DEFAULT_VOLUME
	soundGroup:SetAttribute(CONTROLLED_SOUND_GROUP_ATTRIBUTE, true)
	soundGroup.Parent = SoundService

	return soundGroup
end

function SFX.Bind(sound: Sound): ()
	local backgroundMusic: Instance? = SoundService:FindFirstChild(BACKGROUND_MUSIC_NAME)
	if backgroundMusic and sound:IsDescendantOf(backgroundMusic) then
		return
	end

	-- an authored SoundGroup keeps its effects; mark it UseSFXVolume to follow the SFX volume
	if sound.SoundGroup then
		return
	end

	local parentSoundGroup: SoundGroup? = sound:FindFirstAncestorWhichIsA("SoundGroup")
	if parentSoundGroup and parentSoundGroup:GetAttribute(CONTROLLED_SOUND_GROUP_ATTRIBUTE) == true then
		sound.SoundGroup = parentSoundGroup

		return
	end

	sound.SoundGroup = getSoundGroup()
end

function SFX.SetVolume(volume: number): ()
	local soundGroup: SoundGroup = getSoundGroup()
	local clampedVolume: number = math.clamp(volume, 0, 1)
	soundGroup.Volume = clampedVolume

	local descendants: { Instance } = SoundService:GetDescendants()
	for index: number = 1, #descendants do
		local descendant: Instance = descendants[index]
		if descendant:IsA("SoundGroup") and descendant:GetAttribute(CONTROLLED_SOUND_GROUP_ATTRIBUTE) == true then
			descendant.Volume = clampedVolume
		elseif descendant:IsA("Sound") then
			SFX.Bind(descendant)
		end
	end
end

local function CreateSound(SoundID: string, Volume: number?): Sound
	local Sound = SoundService.SFX.SoundToClone:Clone() :: Sound
	Sound.Parent = SoundService.SFX
	Sound.Name = SoundID
	Sound.Volume = if Volume then Volume else 0.25
	Sound.SoundId = SoundID

	SFX.Bind(Sound)

	return Sound
end

local function AddSoundDebris(Sound: Sound): ()
	local deadline: number = os.clock() + SOUND_LOAD_TIMEOUT
	while Sound.TimeLength <= 0 do
		if os.clock() >= deadline then
			Sound:Destroy()

			return
		end

		task.wait()
	end

	Debris:AddItem(Sound, Sound.TimeLength)
end

local function SetStartTime(Sound: Sound, StartTime: number?): ()
	local startTime: number = StartTime :: number
	if not startTime or startTime <= 0 then
		return
	end

	if Sound.IsLoaded then
		Sound.TimePosition = math.min(startTime, Sound.TimeLength)

		return
	end

	-- TimeLength is unknown until the asset loads, so seek once it has loaded
	Sound.Loaded:Once(function(): ()
		Sound.TimePosition = math.min(startTime, Sound.TimeLength)
	end)
end

function SFX.new(
	SoundID: string | { string },
	Volume: number?,
	DoNotOverlaps: boolean?,
	Randomize: boolean?,
	StartTime: number?
): (Sound | { Sound })?
	if DoNotOverlaps and type(SoundID) == "string" and SoundService.SFX:FindFirstChild(SoundID) then
		return
	end

	if type(SoundID) == "table" then
		if Randomize then
			local soundID: string = SoundID[math.random(1, #SoundID)]
			local Sound = CreateSound(soundID, Volume)
			SetStartTime(Sound, StartTime)
			Sound:Play()
			AddSoundDebris(Sound)

			return Sound
		else
			local CreatedSounds: { Sound } = {}
			for _, soundID: string in SoundID do
				local Sound = CreateSound(soundID, Volume)
				SetStartTime(Sound, StartTime)
				Sound:Play()
				table.insert(CreatedSounds, Sound)
				AddSoundDebris(Sound)
			end

			return CreatedSounds
		end
	else
		local Sound = CreateSound(SoundID, Volume)
		SetStartTime(Sound, StartTime)
		Sound:Play()
		AddSoundDebris(Sound)

		return Sound
	end
end

if RunService:IsClient() then
	SFX.SetVolume(DEFAULT_VOLUME)
end

return SFX
