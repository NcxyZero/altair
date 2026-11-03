# Player

Player-related helpers for reading launch data, checking whether a player favorited the game, detecting console players and triggering gamepad vibration.

## Installation

```bash
bash require-dependency.sh Player
```

```powershell
.\require-dependency.ps1 Player
```

Installed into `src/util/Player`, required as `ReplicatedStorage.util.Player.<Module>`.

## Requirements

- Wally packages: none
- Core utils: none
- Other packages: none

## Modules

### `GetPlayerLaunchData`

Server-only (uses `Player:GetJoinData()`). Polls the player's join data up to `attemptLimit` times (default `10`), waiting `retryDelay` seconds (default `1`) **before** every attempt, until `LaunchData` is not empty. The launch data string is then decoded with `HttpService:JSONDecode()` and the decoded value is returned; `nil` is returned when no launch data arrived. Always yields at least `retryDelay` seconds and up to `attemptLimit * retryDelay` seconds.

```luau
function GetPlayerLaunchData(player: Player, attemptLimit: number?, retryDelay: number?): string?
```

Notes:

- The return type is annotated as `string?`, but the function actually returns the decoded JSON value (usually a table).
- `JSONDecode()` is not wrapped in `pcall`, so launch data that is not valid JSON throws an error.

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetPlayerLaunchData = require(ReplicatedStorage.util.Player.GetPlayerLaunchData)

Players.PlayerAdded:Connect(function(player: Player): ()
  local launchData: any = GetPlayerLaunchData(player, 5, 0.5)
  if not launchData then
    return
  end

  player:SetAttribute("InviteCode", launchData.inviteCode)
end)
```

### `HasPlayerFavorited`

Returns a table with a single `:Check(player)` method. Server-only: it calls `HttpService:GetAsync()` on the roproxy mirror of the legacy `users/favorites/list-json` endpoint (place favorites, `assetTypeId=9`), so **Allow HTTP Requests** must be enabled and the call yields. Returns `true` when any favorite's `UniverseId` equals `game.GameId`, `false` otherwise, and `nil` (with a `warn`) when the request or decoding fails.

```luau
function HasPlayerFavorited:Check(player: Player): boolean?
```

Notes:

- Only the first page (100 favorites) is checked, so players with many favorites may get a false negative.
- It depends on a third-party proxy and a legacy Roblox endpoint, which can stop working at any time.
- Response parsing (`data.Data.Items`) happens outside the `pcall`, so an unexpected response shape throws an error.

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HasPlayerFavorited = require(ReplicatedStorage.util.Player.HasPlayerFavorited)

Players.PlayerAdded:Connect(function(player: Player): ()
  if HasPlayerFavorited:Check(player) then
    player:SetAttribute("FavoriteRewardAvailable", true)
  end
end)
```

### `IsPlayerOnConsole`

Returns `GuiService:IsTenFootInterface()`, which is `true` for console (TV) clients. Takes no arguments and is meaningful only on the client, where it describes the local player's device.

```luau
function IsPlayerOnConsole(): boolean
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IsPlayerOnConsole = require(ReplicatedStorage.util.Player.IsPlayerOnConsole)

local hintText: string = IsPlayerOnConsole() and "Press X to interact" or "Press E to interact"
```

### `Vibrate`

Client-only. Sets a `Gamepad1` vibration motor to full intensity and turns it off after `duration` seconds (default `1 / 30`) with `task.delay()`. The `Small` motor is used when supported, otherwise `Large`; the function does not check `HapticService:IsVibrationSupported()` or whether the `Large` motor is supported. Does not yield.

```luau
function Vibrate(duration: number?): ()
```

Note: overlapping calls share the same motor, so the delayed stop of an earlier call cuts a later, longer vibration short.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Vibrate = require(ReplicatedStorage.util.Player.Vibrate)

local function onDamageTaken(): ()
  if UserInputService.GamepadEnabled then
    Vibrate(0.15)
  end
end
```
