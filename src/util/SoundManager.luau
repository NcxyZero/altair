local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine)

local SoundManager = {}

function SoundManager:GetRandomSound(folder: Folder): Sound
	local sounds: { Sound } = folder:GetChildren() :: any
	return sounds[math.random(#sounds)]
end

function SoundManager:PlaySound(name: string | Folder, parent: (Instance | Vector3)?): ()
	local sound: Sound & { Parent: Instance }

	if type(name) == "string" then
		local soundOrFolder = SoundService:FindFirstChild(name, true)
		if not soundOrFolder then
			return
		end

		if soundOrFolder:IsA("Folder") then
			sound = self:GetRandomSound(soundOrFolder)
		else
			sound = soundOrFolder
		end
	else
		sound = self:GetRandomSound(name)
	end

	if not sound then
		return
	end

	sound = sound:Clone()

	if parent and type(parent) == "vector" then
		local part = Instance.new("Part")
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Anchored = true
		part.Transparency = 1
		part.CFrame = CFrame.new(parent)
		part.Parent = workspace.Terrain
	end

	sound.Parent = parent or workspace
	sound:Play()

	sound.Ended:Once(function(): ()
		if sound.Parent.Parent == workspace.Terrain then
			sound.Parent:Destroy()
		else
			sound:Destroy()
		end
	end)

	return sound
end

function SoundManager:StopMusic(): ()
	local sound: Sound = self.music
	if sound then
		local tween = TweenService:Create(sound, tweenInfo, { Volume = 0 })

		tween.Completed:Once(function(): ()
			sound:Stop()
			sound:Destroy()
		end)

		tween:Play()
	end
end

function SoundManager:PlayMusic(name: string | Folder, parent: (Instance | Vector3)?): ()
	self:StopMusic()

	local sound = self:PlaySound(name, parent)
	if not sound then
		return
	end
	self.music = sound

	local volume: number = sound.Volume
	sound.Volume = 0

	TweenService.Create(sound, tweenInfo, {
		Volume = volume,
	}).Play()

	return sound
end

return SoundManager
