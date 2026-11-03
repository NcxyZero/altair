# Camera

Client-side camera effects: a reference-counted, render-step driven "nudge" (small rotation and FOV kick that eases back) and a simple yielding camera shake.

## Installation

```bash
bash require-dependency.sh Camera
```

```powershell
.\require-dependency.ps1 Camera
```

Installed into `src/util/Camera`, required as `ReplicatedStorage.util.Camera.<Module>`.

## Requirements

- Wally packages: `Maid`
- Core utils: none
- Other packages: none

## Modules

### `CameraNudge`

Singleton that applies a small additive rotation (pitch/yaw) and FOV offset to `workspace.CurrentCamera` every frame, bound with `RunService:BindToRenderStep("CameraNudge_Offset", Enum.RenderPriority.Camera.Value + 1, ...)`, so it runs right after the default camera scripts. Each frame it removes the offset applied last frame and applies the new one, so it composes with the normal camera instead of overwriting it. The render step only runs while at least one reference is held: `StartRef` increments a ref count (binding on the first ref) and returns an idempotent `release` function; if `attachMaid` is given, `release` is also given to that maid. When the count drops to zero the targets are zeroed and the binding is removed once the motion has settled; `StopAll` resets the count and unbinds immediately, restoring the camera CFrame and FOV.

`Nudge` sets a random target rotation: yaw in `[-amplitude, amplitude]` and pitch in `[-amplitude * 1.2, amplitude * 1.2]` (radians), plus a FOV change of `-fovDeltaDeg` (zoom in). `amplitude` defaults to `0.008` and is clamped to `[0, 0.02]`; `fovDeltaDeg` defaults to `1.2` and is clamped to `[0, 4]`. The target decays back to zero (rate 3/s) while the current value eases toward the target (rate 10/s).

`PulseFov` (pending, like `ReleaseFovPulse`: not yet in the published altair-utils Camera package) plays a hold-and-release field-of-view pulse: the FOV snaps in by `peakDeltaDeg` (default `16`, clamped to `[0, 32]`) over 0.22 s with a back-out overshoot and holds there until `ReleaseFovPulse` eases it back over 0.5 s. While a pulse is active it overrides the `Nudge` FOV change; the rotation keeps working. Calling `PulseFov` again restarts the pulse, and `ReleaseFovPulse` without an active, unreleased pulse does nothing.

```luau
CameraNudge:StartRef(maid: Maid.Maid?): () -> ()
CameraNudge:Nudge(amplitude: number?, fovDeltaDeg: number?): ()
CameraNudge:PulseFov(peakDeltaDeg: number?): ()
CameraNudge:ReleaseFovPulse(): ()
CameraNudge:StopAll(): ()
```

Notes: client only. `Nudge` has no visible effect until a reference is held (targets are stored and applied once a ref starts the render step). `PulseFov` starts the render step by itself, and the binding stops after the release when no reference is held. `StopAll` does not invalidate release functions already handed out; calling them afterwards is harmless.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraNudge = require(ReplicatedStorage.util.Camera.CameraNudge)
local Maid = require(ReplicatedStorage.package.Maid)

local maid: Maid.Maid = Maid.new()

CameraNudge:StartRef(maid)
CameraNudge:Nudge()
CameraNudge:Nudge(0.015, 2)

maid:DoCleaning()
```

### `ShakeCamera`

Function that shakes `workspace.CurrentCamera` by offsetting the CFrame captured at call time with `math.noise`-based X/Y translation (in studs), scaled by `strenght` and fading out linearly. It loops on `RunService.RenderStepped:Wait()` and therefore yields until the shake ends, then restores the original CFrame.

```luau
ShakeCamera(strenght: number, duration: number): ()
```

Notes: client only. The real duration is `duration / 10` seconds (passing `5` shakes for 0.5 s). Because it writes `originalCameraCFrame * offset` each frame, any camera movement during the shake is overridden and the camera snaps back to the starting CFrame at the end; prefer `task.spawn` so the caller does not yield. Uses `tick()`.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShakeCamera = require(ReplicatedStorage.util.Camera.ShakeCamera)

task.spawn(ShakeCamera, 0.5, 3)
```
