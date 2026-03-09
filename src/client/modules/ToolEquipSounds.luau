local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Maid = require(ReplicatedStorage.package.Maid)

export type ToolEquipSounds = {
	Bind: (tool: Tool, maid: Maid.Maid?, customEquip: string?, customUnequip: string?) -> Maid.Maid,
	Play: (soundName: string) -> (),
}

local ToolEquipSounds: ToolEquipSounds = {} :: any

local LOCAL_EFFECTS_NAME: string = "LocalEffects"
local EQUIP_SOUND_NAME: string = "Equip"
local UNEQUIP_SOUND_NAME: string = "Unequip"

local function getLocalEffectSound(soundName: string): Sound?
	local localEffects: Instance? = SoundService:FindFirstChild(LOCAL_EFFECTS_NAME)
	if not localEffects then
		localEffects = SoundService:WaitForChild(LOCAL_EFFECTS_NAME, 1)
	end

	if not localEffects then
		return
	end

	local soundInstance: Instance? = localEffects:FindFirstChild(soundName)
	if not soundInstance or not soundInstance:IsA("Sound") then
		return
	end

	local sound: Sound = soundInstance

	return sound
end

function ToolEquipSounds.Play(soundName: string): ()
	local sound: Sound? = getLocalEffectSound(soundName)
	if not sound then
		return
	end

	sound.TimePosition = 0
	SoundService:PlayLocalSound(sound)
end

function ToolEquipSounds.Bind(tool: Tool, maid: Maid.Maid?, customEquip: string?, customUnequip: string?): Maid.Maid
	local connectionMaid: Maid.Maid = maid or Maid.new()

	connectionMaid:GiveTask(tool.Equipped:Connect(function(): ()
		ToolEquipSounds.Play(customEquip or EQUIP_SOUND_NAME)
	end))

	connectionMaid:GiveTask(tool.Unequipped:Connect(function(): ()
		ToolEquipSounds.Play(customUnequip or UNEQUIP_SOUND_NAME)
	end))

	return connectionMaid
end

return ToolEquipSounds
