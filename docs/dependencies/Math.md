# Math

Number helpers for interpolation, range mapping and normalization, plus quadratic bezier points, a camera-space curve layout helper and a simple spring step.

## Installation

```bash
bash require-dependency.sh Math
```

```powershell
.\require-dependency.ps1 Math
```

Installed into `src/util/Math`, required as `ReplicatedStorage.util.Math.<Module>`.

## Requirements

- Wally packages: none
- Core utils: none
- Other packages: none

## Modules

### `GetCurvePositions`

Spreads `ItemCount` world positions over a curve in front of `workspace.CurrentCamera`, for laying out 3D items across the screen (for example, reward previews). Items are split into groups of at most `math.ceil(math.sqrt(ItemCount))`. The first group filled is the center one, then groups alternate outward (center, center - 1, center + 1, ...). Each group is spread along one quadratic bezier that goes from the left edge of the view to the right edge at `ITEM_DISTANCE_FROM_CAMERA` studs, with the middle pushed away from the camera by `CURVE_FLATNESS_FACTOR`. Groups are offset along the camera's `UpVector` by `1 / max` studs per step, so the code calls them "columns" but they show up as rows. When the number of groups is even, everything is also moved 0.2 studs down.

Defaults are `ITEM_DISTANCE_FROM_CAMERA = 1`, `SCREEN_HORIZONTAL_USAGE_SCALE = 0.85` and `CURVE_FLATNESS_FACTOR = 1.25`. The function returns `positions` (keyed by group index, each holding an array of `Vector3`) and `first`, the first group index found while iterating.

```luau
function GetCurvePositions(
  ItemCount: number,
  ITEM_DISTANCE_FROM_CAMERA: number?,
  SCREEN_HORIZONTAL_USAGE_SCALE: number?,
  CURVE_FLATNESS_FACTOR: number?
): ({ { Vector3 } }, number)
```

Notes:

- It reads `workspace.CurrentCamera`, so it only makes sense on the client, and the positions are only valid for the current camera `CFrame`.
- `SCREEN_HORIZONTAL_USAGE_SCALE` has no effect on the curve's end points: `TotalWidth / 2 + Margin` always equals half the view width.
- The control point height is calculated with `FieldOfView / 2`, which gets halved again inside the height helper.
- With `ItemCount = 0` it returns an empty table and `nil`.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetCurvePositions = require(ReplicatedStorage.util.Math.GetCurvePositions)

local positions: { { Vector3 } } = GetCurvePositions(5, 4)

for _group: number, groupPositions: { Vector3 } in positions do
  for _index: number, position: Vector3 in groupPositions do
    print(position)
  end
end
```

### `GetFraction`

Returns the fractional part of a number as `number - math.floor(number)`. Because it uses `math.floor`, negative numbers return the distance from the next lower integer, so `-1.25` returns `0.75`, not `-0.25`.

```luau
function GetFraction(number: number): number
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetFraction = require(ReplicatedStorage.util.Math.GetFraction)

local progress: number = GetFraction(os.clock() / 2)
```

### `GetPointOnQuadBezier`

Returns the point at `t` on a quadratic bezier curve with start `p0`, control `p1` and end `p2`, using `(1 - t)^2 * p0 + 2 * (1 - t) * t * p1 + t^2 * p2`. `t` is not clamped, so values outside `0`-`1` extrapolate past the end points.

```luau
function GetPointOnQuadBezier(t: number, p0: Vector3, p1: Vector3, p2: Vector3): Vector3
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetPointOnQuadBezier = require(ReplicatedStorage.util.Math.GetPointOnQuadBezier)

local startPosition: Vector3 = Vector3.zero
local controlPosition: Vector3 = Vector3.new(0, 20, 10)
local endPosition: Vector3 = Vector3.zAxis * 20
local midPoint: Vector3 = GetPointOnQuadBezier(0.5, startPosition, controlPosition, endPosition)
```

### `InverseLerpNumber`

The inverse of `LerpNumber`: returns where `x` sits between `a` and `b` as `(x - a) / (b - a)`. The result is not clamped, so values outside the range return numbers below `0` or above `1`. If `a == b`, it divides by zero and returns `inf` or `nan`.

```luau
function InverseLerpNumber(a: number, b: number, x: number): number
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InverseLerpNumber = require(ReplicatedStorage.util.Math.InverseLerpNumber)

local healthPercent: number = InverseLerpNumber(0, 200, 150)
```

### `LerpAngle`

Interpolates between two angles in radians along the shortest arc. The difference `b - a` is wrapped into `[-pi, pi)` before it is scaled by `t`, so going from just under `2 * pi` to just over `0` moves forward through `0` instead of turning all the way back. The result is not normalized and can be outside `0`-`2 * pi`.

```luau
function LerpAngle(a: number, b: number, t: number): number
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LerpAngle = require(ReplicatedStorage.util.Math.LerpAngle)

local currentYaw: number = math.rad(350)
local targetYaw: number = math.rad(10)

currentYaw = LerpAngle(currentYaw, targetYaw, 0.2)
```

### `LerpNumber`

Linear interpolation: `current + (target - current) * alpha`. `alpha` is not clamped.

```luau
function LerpNumber(current: number, target: number, alpha: number): number
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LerpNumber = require(ReplicatedStorage.util.Math.LerpNumber)

local value: number = LerpNumber(0, 10, 0.5)
```

### `MapNumber`

Maps `n` from the range `start`-`stop` to the range `newStart`-`newStop`. If `withinBounds` is truthy, the result is clamped to the new range (this works when the new range is reversed too). `factorial` is used as an exponent and defaults to `1`.

```luau
function MapNumber(
  n: number,
  start: number,
  stop: number,
  newStart: number,
  newStop: number,
  withinBounds: number,
  factorial: number
): number
```

Notes:

- Because of operator precedence, the exponent only applies to `(stop - start)`, not to the normalized ratio. With the default `factorial` of `1` the map is linear and correct. Other values do not give a curved mapping.
- `withinBounds` is typed as `number` but is only checked for truthiness, so any number (even `0`) turns clamping on. Pass `nil` to turn it off.
- The function is declared without `local` (`function mapNumberSquarely`), so it also creates a global.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapNumber = require(ReplicatedStorage.util.Math.MapNumber)

local transparency: number = MapNumber(35, 0, 100, 1, 0, 1, 1)
```

### `NormalizeScale`

A table of helpers for working with a value inside a `minScale`-`maxScale` range. Every argument goes through `tonumber`, so numeric strings work, and `nil` or invalid values become `0`.

- `ComputeRange(minScale, maxScale)` returns `maxScale - minScale`, but never less than `1e-6`, so dividing by it is always safe.
- `ClampScale(value, minScale, maxScale)` clamps `value` between `minScale` and `maxScale`. If `maxScale` is missing, `minScale` is used as the maximum (or `1` if both are missing). `math.clamp` errors when the maximum is lower than the minimum.
- `PercentFromScale(value, minScale, maxScale)` returns where `value` sits in the range, clamped to `0`-`1`.

```luau
NormalizeScale.ComputeRange(minScale: number, maxScale: number): number
NormalizeScale.ClampScale(value: number, minScale: number, maxScale: number): number
NormalizeScale.PercentFromScale(value: number, minScale: number, maxScale: number): number
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NormalizeScale = require(ReplicatedStorage.util.Math.NormalizeScale)

local scale: number = NormalizeScale.ClampScale(2.5, 0.5, 2)
local percent: number = NormalizeScale.PercentFromScale(scale, 0.5, 2)
```

### `Spring`

Moves a 1D damped spring forward by one step and returns the new `(position, velocity)`. It uses semi-implicit Euler integration: acceleration is `-stiffness * (start - goal) - dampening * velocity`, velocity is updated first, then position. `alpha` is the time step (usually the frame delta time) and is capped at `0.05` to keep the spring stable. The function is pure, so you store the returned values and pass them back in on the next frame.

```luau
function Spring(
  start: number,
  velocity: number,
  goal: number,
  stiffness: number,
  dampening: number,
  precision: number,
  alpha: number
): (number, number)
```

Notes:

- When both the new velocity and the position change are smaller than `precision`, it snaps to `goal` with velocity `0`.
- If the result becomes `NaN` or `+inf`, it returns the original `start` and `velocity` instead. `-inf` is not checked.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Spring = require(ReplicatedStorage.util.Math.Spring)

local position: number = 0
local velocity: number = 0
local goal: number = 10

RunService.RenderStepped:Connect(function(deltaTime: number): ()
  position, velocity = Spring(position, velocity, goal, 120, 12, 0.001, deltaTime)
end)
```
