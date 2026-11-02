# Geometry

Closest-part searches around the local character and checks whether a point lies inside a part or an oriented box.

## Installation

```bash
./require-dependency.sh Geometry
```

```powershell
.\require-dependency.ps1 Geometry
```

Installed into `src/util/Geometry`, required as `ReplicatedStorage.util.Geometry.<Module>`.

## Requirements

- Wally packages: none
- Core utils: none
- Other packages: none

## Modules

### `FindClosestBasePartInRange`

Client-only (uses `Players.LocalPlayer`). Returns the part from `baseParts` closest to the local character, measured with `Player:DistanceFromCharacter()` (distance from the character's head to `basePart.Position`), ignoring parts farther than `range` (the limit is inclusive). Returns `nil` when no part is in range.

```luau
function FindClosestBasePartInRange(baseParts: { BasePart }, range: number): BasePart?
```

Note: `DistanceFromCharacter()` returns `0` when the local player has no character, so in that case the first part of the array is returned regardless of `range`.

```luau
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FindClosestBasePartInRange = require(ReplicatedStorage.util.Geometry.FindClosestBasePartInRange)

local shops: { BasePart } = CollectionService:GetTagged("Shop") :: any
local closestShop: BasePart? = FindClosestBasePartInRange(shops, 20)
if closestShop then
  closestShop:SetAttribute("Highlighted", true)
end
```

### `FindClosestBasePartInRange2D`

Client-only variant that ignores height: distance is measured on the X/Z plane between `LocalPlayer.Character:GetPivot()` and each part's `CFrame` position. Parts farther than `range` (inclusive) are skipped. Returns `nil` when the local player has no character or no part is in range.

```luau
function FindClosestBasePartInRange2D(baseParts: { BasePart }, range: number): BasePart?
```

```luau
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FindClosestBasePartInRange2D = require(ReplicatedStorage.util.Geometry.FindClosestBasePartInRange2D)

local pads: { BasePart } = CollectionService:GetTagged("JumpPad") :: any
local closestPad: BasePart? = FindClosestBasePartInRange2D(pads, 12)
```

### `IsPartInsidePart`

Despite the module name, it checks whether a **point** is inside a part. The point is converted into the part's object space and compared against half of `part.Size + Vector3.one * padding` on every axis, so rotation is respected and the part is treated as a box (its actual shape, such as a ball or wedge, is ignored). `padding` is added to the full size, meaning each face grows by `padding / 2`; it can be negative and defaults to `0`. Borders count as inside.

```luau
function IsPartInsidePart(point: Vector3, part: BasePart, padding: number?): boolean
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IsPartInsidePart = require(ReplicatedStorage.util.Geometry.IsPartInsidePart)

local safeZone: BasePart = workspace:WaitForChild("SafeZone") :: any

local function isInSafeZone(player: Player): boolean
  local character: Model? = player.Character
  if not character then
    return false
  end

  return IsPartInsidePart(character:GetPivot().Position, safeZone, 2)
end
```

### `IsPointInsideBounds`

Same check as `IsPartInsidePart`, but against an arbitrary oriented box described by `origin` (box center) and `boundsSize`, which makes it a good fit for `Model:GetBoundingBox()`. `padding` is added to the full size (each face grows by `padding / 2`) and defaults to `0`.

```luau
function IsPointInsideBounds(point: Vector3, origin: CFrame, boundsSize: Vector3, padding: number?): boolean
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IsPointInsideBounds = require(ReplicatedStorage.util.Geometry.IsPointInsideBounds)

local arena: Model = workspace:WaitForChild("Arena") :: any
local arenaCFrame: CFrame, arenaSize: Vector3 = arena:GetBoundingBox()
local isInside: boolean = IsPointInsideBounds(Vector3.new(10, 5, 0), arenaCFrame, arenaSize)
```
