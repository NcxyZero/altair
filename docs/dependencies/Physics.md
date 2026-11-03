# Physics

Helpers for computing the mass of a model and welding all of its parts to the primary part.

## Installation

```bash
bash require-dependency.sh Physics
```

```powershell
.\require-dependency.ps1 Physics
```

Installed into `src/util/Physics`, required as `ReplicatedStorage.util.Physics.<Module>`.

## Requirements

- Wally packages: none
- Core utils: none
- Other packages: none

## Modules

### `GetModelMass`

Returns the sum of `BasePart:GetMass()` for every `BasePart` descendant of `model`, skipping parts with `Massless` set to `true`. Works on models outside the workspace, and does not take connected assemblies outside the model into account.

```luau
function GetModelMass(model: Model): number
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetModelMass = require(ReplicatedStorage.util.Physics.GetModelMass)

local cart: Model = workspace:WaitForChild("Cart") :: any
local liftForce: number = GetModelMass(cart) * workspace.Gravity
```

### `WeldModel`

Welds every `BasePart` descendant of `model` to `model.PrimaryPart` with a `Weld` parented to that part, keeping the current offsets (`C0 = PrimaryPart.CFrame:Inverse() * basePart.CFrame`, `C1 = CFrame.identity`), and sets `Anchored = false` on each welded part. The primary part itself is not unanchored, so unanchor it yourself when the model should move physically.

```luau
function WeldModel(model: Model): ()
```

Notes:

- `model.PrimaryPart` must be set, otherwise the call errors.
- Parts that already have a child named `Weld` are skipped. This makes repeated calls safe, but also skips parts that contain any unrelated instance named `Weld`.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeldModel = require(ReplicatedStorage.util.Physics.WeldModel)

local crate: Model = ReplicatedStorage:WaitForChild("Crate"):Clone() :: any

WeldModel(crate)

local primaryPart: BasePart = crate.PrimaryPart :: any
primaryPart.Anchored = false

crate:PivotTo(CFrame.new(0, 20, 0))

crate.Parent = workspace
```
