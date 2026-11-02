local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

export type SFX = {
	new: (
		SoundID: string | { string },
		Volume: number?,
		DoNotOverlaps: boolean?,
		Randomize: boolean?
	) -> (Sound | { Sound })?,
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

local function CreateSound(SoundID: string, Volume: number?): Sound
	local Sound = SoundService.SFX.SoundToClone:Clone() :: Sound
	Sound.Parent = SoundService.SFX
	Sound.Name = SoundID
	Sound.Volume = if Volume then Volume else 0.25
	Sound.SoundId = SoundID

	return Sound
end

local function AddSoundDebris(Sound: Sound): ()
	while Sound.TimeLength <= 0 do
		task.wait()
	end
	Debris:AddItem(Sound, Sound.TimeLength)
end

function SFX.new(
	SoundID: string | { string },
	Volume: number?,
	DoNotOverlaps: boolean?,
	Randomize: boolean?
): (Sound | { Sound })?
	if DoNotOverlaps and SoundService.SFX:FindFirstChild(SoundID) then
		return
	end

	if type(SoundID) == "table" then
		if Randomize then
			local soundID: string = SoundID[math.random(1, #SoundID)]
			local Sound = CreateSound(soundID, Volume)
			Sound:Play()
			AddSoundDebris(Sound)

			return Sound
		else
			local CreatedSounds: { Sound } = {}
			for _, soundID: string in SoundID do
				local Sound = CreateSound(soundID, Volume)
				Sound:Play()
				table.insert(CreatedSounds, Sound)
				AddSoundDebris(Sound)
			end

			return CreatedSounds
		end
	else
		local Sound = CreateSound(SoundID, Volume)
		Sound:Play()
		AddSoundDebris(Sound)

		return Sound
	end
end

return SFX
