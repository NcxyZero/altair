# Effects

Visual feedback effects: expanding ripples at a screen position, a full-screen confetti burst with sound, and short-lived text above a part or character.

## Installation

```bash
bash require-dependency.sh Effects
```

```powershell
.\require-dependency.ps1 Effects
```

Installed into `src/util/Effects`, required as `ReplicatedStorage.util.Effects.<Module>`.

## Requirements

- Wally packages: `Maid`
- Core utils: `Logger`, `PlayerGui`, `SFX`
- Other packages: none

## Modules

### `ClickRipple`

Client-only singleton that draws a white, circular ripple (`Frame` with `UICorner` and `UIStroke`) which grows from 8 px to 20% of the screen's larger side (clamped to 60–110 px) and fades out over 0.25 s (`Quad`, `Out`), then destroys itself. Ripples live in a `ScreenGui` named `ClickRipple` (`DisplayOrder` 999, `ResetOnSpawn` false, `IgnoreGuiInset` false) that is reused if it already exists in `PlayerGui`, otherwise created.

```luau
ClickRipple:Enable(): ()
ClickRipple:Disable(): ()
ClickRipple:IsEnabled(): boolean
ClickRipple:FireAtPosition(position: Vector2): ()
```

The module does not listen to input itself: call `FireAtPosition` from your own input handler. It starts disabled and `FireAtPosition` does nothing until `Enable` is called. `position` is an offset inside the inset-respecting container, so use `InputObject.Position` (which excludes the top bar inset); `UserInputService:GetMouseLocation()` includes the inset and would place the ripple too low.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ClickRipple = require(ReplicatedStorage.util.Effects.ClickRipple)

ClickRipple:Enable()

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean): ()
  if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
    return
  end

  ClickRipple:FireAtPosition(Vector2.new(input.Position.X, input.Position.Y))
end)
```

### `Confetti`

Client-only table with a `Show` method that creates a `ScreenGui` named `Confetti` (`DisplayOrder` -10, so it renders behind most UI) in the local player's `PlayerGui`, spawns `amount` colored frames, plays `SFX.Sounds.Confetti` through the core `SFX` util, and animates the frames on `RunService.PreAnimation`: each piece arcs from a random start point, then falls and spins until it leaves the screen. `Show` yields until every piece is gone, then destroys the `ScreenGui` and cleans its `Maid`.

```luau
Confetti:Show(amount: number): ()
```

Notes:

- `SFX` expects `SoundService.SFX.SoundToClone` to exist.
- Piece size is divided by `10 - math.random(10)`, so roughly 1 in 10 pieces gets a division by zero (infinite size) and covers the screen until it falls off.
- The arc/fall state (`finished`) is shared between all pieces instead of being per piece.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Confetti = require(ReplicatedStorage.util.Effects.Confetti)

task.spawn(function(): ()
  Confetti:Show(60)
end)
```

### `OverheadText`

Creates a `BillboardGui` named `OverheadText` (64x64 px, `AlwaysOnTop`, 4 studs above the target in world space) with a scaled `FredokaOne` `TextLabel` and returns it. `adornee` may be a `BasePart` or a `Model` with a `HumanoidRootPart`; otherwise it warns through `Logger` and parents the gui to `workspace` without an adornee (so it will not be visible). The gui is destroyed after `seconds` (default `1`) via `task.delay`, or earlier when the optional `maid` is cleaned. Called with `.`, not `:`; works on the server (replicated) and the client (local only).

```luau
OverheadText.Show(adornee: Instance, text: string, color: Color3?, seconds: number?, maid: Maid.Maid?): BillboardGui
```

Note: the default text color is black, the same as the text stroke, so pass a `color` for readable text.

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OverheadText = require(ReplicatedStorage.util.Effects.OverheadText)

local character: Model? = Players.LocalPlayer.Character
if character then
  OverheadText.Show(character, "+100", Color3.fromRGB(85, 255, 127), 1.5)
end
```
