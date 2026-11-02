# Misc

Small general-purpose helpers: enum item lookup by name, a callable switch object, and a Studio tool for reacting to events or property changes on matching instances.

## Installation

```bash
./require-dependency.sh Misc
```

```powershell
.\require-dependency.ps1 Misc
```

Installed into `src/util/Misc`, required as `ReplicatedStorage.util.Misc.<Module>`.

## Requirements

- Wally packages: none
- Core utils: none
- Other packages: none

## Modules

### `GetEnumItem`

Looks up an `EnumItem` by its exact (case-sensitive) `Name` by iterating `enum:GetEnumItems()`. Returns `nil` when either argument is missing or no item matches, which makes it safe for names coming from attributes or configuration.

```luau
function GetEnumItem(enum: Enum, item: string): EnumItem?
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetEnumItem = require(ReplicatedStorage.util.Misc.GetEnumItem)

local floor: BasePart = workspace:WaitForChild("Floor") :: any
local material: EnumItem? = GetEnumItem(Enum.Material, floor:GetAttribute("MaterialName") :: any)
if material then
  floor.Material = material :: any
end
```

### `RegisterInstanceAction`

Connects `callback` to an event or property of every descendant of `scope` whose class matches `className` (`IsA`), covering both existing descendants and ones added later through `DescendantAdded`. If `eventOrPropertyName` resolves to an `RBXScriptSignal` it is connected directly (the callback receives the event arguments); otherwise `GetPropertyChangedSignal()` is used (the callback receives no arguments, so it does not know which instance changed). By default it only runs in Studio and returns `nil` elsewhere or when `scope` is `nil`; pass `allowOutsideStudio = true` to lift that. Returns a cleanup function that disconnects everything.

```luau
function RegisterInstanceAction(
  scope: Instance,
  className: string,
  eventOrPropertyName: string,
  callback: (...any) -> (),
  allowOutsideStudio: true?
): (() -> ())?
```

Notes:

- Properties whose current value is `false` or `nil` (for example `Anchored` on an unanchored part) hit the "not found" check and are skipped with a warning.
- A name that is not a member of the class makes `instance[eventOrPropertyName]` throw an error instead of warning.
- Connections to descendants that are later removed stay in the internal table until the cleanup function is called.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RegisterInstanceAction = require(ReplicatedStorage.util.Misc.RegisterInstanceAction)

local stopTracking: (() -> ())? = RegisterInstanceAction(workspace, "BasePart", "Size", function(): ()
  print("A part was resized")
end)

task.delay(60, function(): ()
  if stopTracking then
    stopTracking()
  end
end)
```

### `Switch`

Creates a callable switch object. Cases are registered by assigning functions to keys (`switch[key] = callback`), and calling `switch(key)` runs the matching callback, or `default` when no case matches and `default` is a function. Callbacks receive no arguments and their return values are discarded; a non-function `default` is ignored.

```luau
function Switch(default: any): any
```

Note: reading `switch[key]` always returns `nil`, because cases are stored in a hidden table and there is no `__index` metamethod.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Switch = require(ReplicatedStorage.util.Misc.Switch)

local onRarity: any = Switch(function(): ()
  print("Unknown rarity")
end)

onRarity.Common = function(): ()
  print("Common drop")
end

onRarity.Legendary = function(): ()
  print("Legendary drop")
end

onRarity("Legendary")
```
