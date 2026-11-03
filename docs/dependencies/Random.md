# Random

Random selection helpers: weighted picks by chance or rarity, random array elements and dictionary keys, and random points inside a part.

## Installation

```bash
bash require-dependency.sh Random
```

```powershell
.\require-dependency.ps1 Random
```

Installed into `src/util/Random`, required as `ReplicatedStorage.util.Random.<Module>`.

## Requirements

- Wally packages: none
- Core utils: none
- Other packages: none

## Modules

### `GetRandom`

Picks one entry from `rewards` using each entry's `chance` field as a weight. It adds the chances into running totals, rolls `math.random(total)` and returns the first entry whose running total is greater than or equal to the roll. The whole entry table is returned, so it can carry any extra fields.

```luau
function GetRandom(rewards: { { chance: number, [any]: any } })
```

The return type is not annotated in the source. It returns the chosen entry, or `nil` if nothing matched.

Notes:

- Chances should be positive integers, because `math.random(total)` works with integers. An empty `rewards` table makes `math.random(0)` throw an error.
- The second loop goes through a table keyed by running totals. Luau does not guarantee the order of that loop, so the first match is not always the lowest bucket that fits, and the real odds can differ from the weights.
- Entries with `chance = 0` share a running total with the entry before them and overwrite it.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetRandom = require(ReplicatedStorage.util.Random.GetRandom)

local rewards: { { chance: number, name: string } } = {
  { chance = 70, name = "Coins" },
  { chance = 25, name = "Gems" },
  { chance = 5, name = "Pet" },
}

local reward: { chance: number, name: string } = GetRandom(rewards)

print(reward.name)
```

### `GetRandomFromArray`

Returns a random element of an array using `math.random(1, #array)`. An empty array throws an error (`interval is empty`).

```luau
function GetRandomFromArray<T>(array: { T }): T
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetRandomFromArray = require(ReplicatedStorage.util.Random.GetRandomFromArray)

local spawnNames: { string } = { "North", "South", "East", "West" }
local spawnName: string = GetRandomFromArray(spawnNames)
```

### `GetRandomItemByWeight`

Picks a key from a dictionary of drop configs where `Weight` means rarity in a "1 in `Weight`" sense. Each item is rolled on its own with `math.random(1, Weight // luck)`, and it succeeds on a roll of `1`. If several items succeed, the one with the highest `Weight` (the rarest) is returned. If none succeed, the item with the lowest `Weight` (the most common) is returned. `luckToConsider` defaults to `1`, and higher values divide each weight, which makes rare items more likely.

```luau
function GetRandomItemByWeight(
  itemsPossibleToDrop: { [string]: { Weight: number, [any]: any } },
  luckToConsider: number?
): string
```

Notes:

- If `Weight // luck` drops below `1` (luck higher than an item's weight), `math.random(1, 0)` throws an error.
- An empty table returns `nil`.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetRandomItemByWeight = require(ReplicatedStorage.util.Random.GetRandomItemByWeight)

local drops: { [string]: { Weight: number } } = {
  Common = { Weight = 2 },
  Rare = { Weight = 50 },
  Legendary = { Weight = 1000 },
}

local dropName: string = GetRandomItemByWeight(drops, 2)
```

### `GetRandomKeyFromTable`

Returns a random key from a dictionary. It collects all keys into an array and picks one with `Random.new():NextInteger(1, #keys)`.

```luau
function GetRandomKeyFromTable<T>(dictionary: { [T]: any }): T
```

Notes:

- When the dictionary has exactly one key, it returns that key's value instead of the key, which is probably a bug.
- An empty dictionary is not handled.
- It uses `pairs()` inside, which goes against the project style.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetRandomKeyFromTable = require(ReplicatedStorage.util.Random.GetRandomKeyFromTable)

local maps: { [string]: number } = {
  Desert = 1,
  Forest = 2,
  Snow = 3,
}

local mapName: string = GetRandomKeyFromTable(maps)
```

### `GetRandomPositionInsideObject`

Returns a random world position inside a `BasePart`'s oriented bounding box. It picks a random offset within `±Size / 2` on each local axis and converts it to world space with `object.CFrame:ToWorldSpace`, so rotated parts work. All calls share one module-level `Random` object. It only uses the box, so for spheres, wedges, cylinders or meshes the position can be outside the visible shape.

```luau
function GetRandomPositionInsideObject(object: BasePart): Vector3
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetRandomPositionInsideObject = require(ReplicatedStorage.util.Random.GetRandomPositionInsideObject)

local spawnArea: BasePart = workspace:WaitForChild("SpawnArea")
local spawnPosition: Vector3 = GetRandomPositionInsideObject(spawnArea)
```
