# Audio

Small sound playback helper that clones sounds from `SoundService` (optionally picking a random sound from a folder), plays them and cleans them up, plus basic music playback with fades.

## Installation

```bash
bash require-dependency.sh Audio
```

```powershell
.\require-dependency.ps1 Audio
```

Installed into `src/util/Audio`, required as `ReplicatedStorage.util.Audio.<Module>`.

## Requirements

- Wally packages: none
- Core utils: none
- Other packages: none

## Modules

### `SoundManager`

Table of methods (call with `:`). Sounds are expected to live somewhere under `SoundService`: a `Sound` is used directly, a `Folder` is treated as a pool of variants. All fades use `TweenInfo.new(0.5, Enum.EasingStyle.Sine)`.

```luau
SoundManager:GetRandomSound(folder: Folder): Sound
SoundManager:PlaySound(name: string | Folder, parent: (Instance | Vector3)?): Sound?
SoundManager:PlayMusic(name: string | Folder, parent: (Instance | Vector3)?): Sound?
SoundManager:StopMusic(): ()
```

- `GetRandomSound` returns a random child of `folder` (it does not check classes; an empty folder errors in `math.random(0)`).
- `PlaySound` resolves `name` with `SoundService:FindFirstChild(name, true)` (recursive, first match), picks a random child if it is a `Folder`, clones it, parents the clone to `parent` or `workspace`, plays it and destroys it on `Ended`. Returns the clone, or nothing if the name is not found (the type annotation says `()` but a `Sound` is returned).
- `PlayMusic` calls `StopMusic`, plays the sound through `PlaySound`, stores it in `SoundManager.music` and tries to fade its volume in from 0.
- `StopMusic` fades the current `music` to volume 0, then stops and destroys it. It does not clear `SoundManager.music`.

Notes:

- `PlayMusic` is broken: the fade-in uses `TweenService.Create(...)` / `.Play()` with a dot instead of a colon, so it errors after the volume was set to 0, leaving the music playing silently.
- Passing a `Vector3` as `parent` is broken: a helper `Part` is created in `workspace.Terrain` but the sound is still parented to the `Vector3` itself, which errors (and leaks the part). Pass an `Instance` instead.
- `Looped` sounds never fire `Ended`, so they are never destroyed by `PlaySound`.

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundManager = require(ReplicatedStorage.util.Audio.SoundManager)

local character: Model? = Players.LocalPlayer.Character
if character and character.PrimaryPart then
  SoundManager:PlaySound("Footsteps", character.PrimaryPart)
end

SoundManager:PlaySound("ButtonClick")
SoundManager:StopMusic()
```
