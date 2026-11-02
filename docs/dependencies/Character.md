# Character

Helpers for finding player characters, moving and teleporting them, and running async work that is cancelled as soon as a character is removed.

## Installation

```bash
./require-dependency.sh Character
```

```powershell
.\require-dependency.ps1 Character
```

Installed into `src/util/Character`, required as `ReplicatedStorage.util.Character.<Module>`.

## Requirements

- Wally packages: `Maid`, `Promise`
- Core utils: `Logger`
- Other packages: none

## Modules

### `GetPlayerCharacters`

Returns an array with the current `Character` of every player in `Players:GetPlayers()`. Players without a character are skipped, unless `waitForAll` is `true`, in which case the function yields on `CharacterAdded:Wait()` for each player that has no character yet (one after another), so the call can block for a long time and never returns if a waited player leaves before spawning.

```luau
function GetPlayerCharacters(waitForAll: true?): { Model }
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetPlayerCharacters = require(ReplicatedStorage.util.Character.GetPlayerCharacters)

local characters: { Model } = GetPlayerCharacters(true)

for _index: number, character: Model in characters do
  character:SetAttribute("InRound", true)
end
```

### `GetPlayerPrimaryPart`

Returns `player.Character.PrimaryPart` (usually the `HumanoidRootPart`), or `nil` when the player has no character or the character has no `PrimaryPart`. Never yields.

```luau
function GetPlayerPrimaryPart(player: Player): BasePart?
```

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetPlayerPrimaryPart = require(ReplicatedStorage.util.Character.GetPlayerPrimaryPart)

local function getPlayerPosition(player: Player): Vector3?
  local primaryPart: BasePart? = GetPlayerPrimaryPart(player)
  if not primaryPart then
    return
  end

  return primaryPart.Position
end

local position: Vector3? = getPlayerPosition(Players:GetPlayers()[1])
```

### `MoveToWithoutTimeout`

Calls `humanoid:MoveTo(targetPoint)` and re-issues it every 6 seconds, which bypasses the built-in 8 second `MoveTo` timeout. Returns a `Promise` that resolves on the first `Humanoid.MoveToFinished` (the `reached` flag is ignored). The refresh loop stops when the humanoid loses its parent or `WalkToPoint` changes (for example another `MoveTo` call).

```luau
function MoveToWithoutTimeout(humanoid: Humanoid, targetPoint: Vector3): Promise
```

Note: when the loop stops early, its `Maid` disconnects the `MoveToFinished` listener, so the promise stays pending forever instead of rejecting. Add a `:timeout()` if you need a guaranteed settle.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MoveToWithoutTimeout = require(ReplicatedStorage.util.Character.MoveToWithoutTimeout)

local guide: Model = workspace:WaitForChild("Guide") :: any
local humanoid: Humanoid = guide:WaitForChild("Humanoid") :: any

MoveToWithoutTimeout(humanoid, Vector3.new(120, 3, -45)):timeout(30):andThen(function(): ()
  guide:SetAttribute("Arrived", true)
end)
```

### `SecureCharacterAsync`

Races the given promises against an internal promise that rejects (with no value) when `player.CharacterRemoving` fires, so the chain fails as soon as the character respawns or the player leaves. Because it uses `Promise.race`, the losing promises are cancelled. Returns an immediately rejected promise when `player` is `nil`. The listener is cleaned up with `finallyCall`, and a `Logger.print` message is written when the character is removed (Studio only).

```luau
function SecureCharacterAsync<T>(player: Player, ...: TypedPromise<T>): TypedPromise<T | any>
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.package.Promise)
local SecureCharacterAsync = require(ReplicatedStorage.util.Character.SecureCharacterAsync)

local function channelCapture(player: Player): ()
  SecureCharacterAsync(player, Promise.delay(5))
    :andThen(function(): ()
      player:SetAttribute("Captured", true)
    end)
    :catch(function(): ()
      player:SetAttribute("Captured", false)
    end)
end
```

### `TeleportCharacter`

Moves a character to `target` with `character:PivotTo()`. Unless `keepSitting` is `true`, a seated character is first unseated: the seat's `SeatWeld` is destroyed, `Humanoid.Sit` is set to `false` and the function yields one frame (`task.wait()`). Returns `false` when the character is `nil` or has no `Humanoid`, otherwise `true`.

```luau
function TeleportCharacter(character: Model, target: CFrame, keepSitting: true?): boolean
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TeleportCharacter = require(ReplicatedStorage.util.Character.TeleportCharacter)

local spawnPoint: BasePart = workspace:WaitForChild("LobbySpawn") :: any

local function sendToLobby(player: Player): boolean
  local character: Model? = player.Character
  if not character then
    return false
  end

  return TeleportCharacter(character, spawnPoint.CFrame + Vector3.yAxis * 3)
end
```
