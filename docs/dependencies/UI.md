# UI

GUI helpers: changing a `GuiObject`'s anchor point while repositioning it, revealing text with a typewriter effect, and tweening a number for animated counters.

## Installation

```bash
bash require-dependency.sh UI
```

```powershell
.\require-dependency.ps1 UI
```

Installed into `src/util/UI`, required as `ReplicatedStorage.util.UI.<Module>`.

## Requirements

- Wally packages: none
- Core utils: none
- Other packages: none

## Modules

### `AnchorPointAdjustments`

Single method that sets `guiObject.AnchorPoint` to `newAnchorPoint` and recomputes `Position` from the object's current `AbsolutePosition` and `AbsoluteSize`. If the parent is a `GuiObject`, the result is written as scale relative to the parent's `AbsoluteSize`; otherwise (for example directly under a `ScreenGui`) it is written as offset.

```luau
AnchorPointAdjustments:AdjustPosition(guiObject: GuiObject, newAnchorPoint: Vector2): ()
```

Note: the new position is computed as `oldPivot - size * newAnchorPoint` (where `oldPivot = absolutePosition + size * oldAnchorPoint`), not `absolutePosition + size * newAnchorPoint`, and the parent's `AbsolutePosition` is not subtracted. The element only keeps its on-screen place in specific cases (for example `(1, 1)` to `(0.5, 0.5)` in a parent at the screen origin), so verify the result visually.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnchorPointAdjustments = require(ReplicatedStorage.util.UI.AnchorPointAdjustments)
local PlayerGui = require(ReplicatedStorage.util.Core.PlayerGui)

local frame: Frame = PlayerGui:WaitFor("Main"):WaitForChild("Frame")

AnchorPointAdjustments:AdjustPosition(frame, Vector2.one * 0.5)
```

### `PlayTypewrite`

Function that sets `guiObject.Text = text` and reveals it one character at a time through `MaxVisibleGraphemes`, waiting `duration / #text` seconds per character. Spaces are revealed without waiting and `,`, `.`, `!`, `?` wait twice as long, so the total time is only approximately `duration`. It yields until the whole text is shown and leaves `MaxVisibleGraphemes` at `#text`.

```luau
PlayTypewrite(text: string, guiObject: TextLabel, duration: number): ()
```

Note: it iterates bytes (`#text`, `text:sub`), while `MaxVisibleGraphemes` counts graphemes, so multi-byte UTF-8 characters and rich text tags reveal unevenly. A commented-out typing sound is left in the source.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayTypewrite = require(ReplicatedStorage.util.UI.PlayTypewrite)
local PlayerGui = require(ReplicatedStorage.util.Core.PlayerGui)

local label: TextLabel = PlayerGui:WaitFor("Dialog"):WaitForChild("Text")

PlayTypewrite("Welcome back, adventurer!", label, 2)
```

### `TweenNumber`

Class wrapping a `NumberValue` (`self.Number`) whose value is tweened with a default `TweenInfo` of `animationTime` seconds. `new(animationTime, startingValue)` starts at `startingValue` (or `0`). `Add` and `Set` tween toward `desiredValue + value` / `newValue` and call `onTweenEnd` when the tween completes, unless `Stop` was called meanwhile. `Reset` and `ResetToStarting` go to `0` / `startingValue`, tweened when `animatable` is true or set instantly otherwise. `Stop` freezes the value by playing a zero-length tween to the current value (its argument is ignored). `OnChange` connects a callback receiving the new value; `Destroy` destroys the `NumberValue`, which also disconnects `OnChange` callbacks.

```luau
TweenNumber.new(animationTime: number, startingValue: number): TweenNumber
TweenNumber:Add(value: number, onTweenEnd: () -> ()): ()
TweenNumber:Set(newValue: number, onTweenEnd: () -> ()): ()
TweenNumber:Reset(animatable: boolean): ()
TweenNumber:ResetToStarting(animatable: boolean): ()
TweenNumber:Stop(animatable: boolean): ()
TweenNumber:ChangeTweenTime(animationTime: number): ()
TweenNumber:OnChange(onChangeFunction: (newValue: number) -> ()): ()
TweenNumber:Destroy(): ()
```

Notes:

- `onTweenEnd` is required: it is called without a nil check, so omitting it errors when the tween completes.
- The `Completed` handler does not check the playback state, so a tween interrupted by a newer `Add`/`Set` can still run its `onTweenEnd` early.
- `Add` adds to `desiredValue` (the last target), not the current value, even after `Stop`.
- `ResetToStarting` errors if `new` was called without `startingValue`.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerGui = require(ReplicatedStorage.util.Core.PlayerGui)
local TweenNumber = require(ReplicatedStorage.util.UI.TweenNumber)

local label: TextLabel = PlayerGui:WaitFor("Hud"):WaitForChild("Coins")
local coins: TweenNumber.TweenNumber = TweenNumber.new(0.5, 0)

coins:OnChange(function(newValue: number): ()
  label.Text = tostring(newValue // 1)
end)

coins:Add(250, function(): ()
  label.TextColor3 = Color3.new(1, 1, 1)
end)
```
