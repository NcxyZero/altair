# Table

Small table helpers: find by predicate, count dictionary entries, get keys or values as arrays, and merge arrays.

## Installation

```bash
./require-dependency.sh Table
```

```powershell
.\require-dependency.ps1 Table
```

Installed into `src/util/Table`, required as `ReplicatedStorage.util.Table.<Module>`.

## Requirements

- Wally packages: none
- Core utils: none
- Other packages: none

## Modules

### `FindUtility`

A table with two search functions, named in lowercase: `findValue` and `findKey`. Both loop through `input` and call `callback(value, key)` on each entry. `findValue` returns the first value where the callback returns `true`, and `findKey` returns that entry's key. Both return `nil` when nothing matches. For dictionaries the loop order is not defined, so if several entries match, there is no guarantee which one you get.

```luau
FindUtility.findValue<K, V>(input: { [K]: V }, callback: (V, K) -> boolean): V?
FindUtility.findKey<K, V>(input: { [K]: V }, callback: (V, K) -> boolean): K?
```

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FindUtility = require(ReplicatedStorage.util.Table.FindUtility)

local admin: Player? = FindUtility.findValue(Players:GetPlayers(), function(player: Player, _index: number): boolean
  return player:GetAttribute("Admin") == true
end)
```

### `GetDictionaryLength`

Counts every entry in a table, both array and hash parts, since `#` only counts the array part. Passing `nil` returns `0`.

```luau
function GetDictionaryLength(dictionary: { [any]: any }): number
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetDictionaryLength = require(ReplicatedStorage.util.Table.GetDictionaryLength)

local inventory: { [string]: number } = { Sword = 1, Shield = 1, Potion = 5 }
local itemTypes: number = GetDictionaryLength(inventory)
```

### `GetKeysFromTable`

Returns a new array with all keys of `data`. For dictionaries the order is not defined. Passing `nil` throws an error.

```luau
function GetKeysFromTable(data: { [any]: any }): { any }
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetKeysFromTable = require(ReplicatedStorage.util.Table.GetKeysFromTable)

local inventory: { [string]: number } = { Sword = 1, Shield = 1, Potion = 5 }
local itemNames: { string } = GetKeysFromTable(inventory)
```

### `GetValuesFromTable`

Returns a new array with all values of `dictionary`. The parameter is typed as `{ [string]: any }`, but any table works at runtime. For dictionaries the order is not defined.

```luau
function GetValuesFromTable(dictionary: { [string]: any }): { any }
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetValuesFromTable = require(ReplicatedStorage.util.Table.GetValuesFromTable)

local inventory: { [string]: number } = { Sword = 1, Shield = 1, Potion = 5 }
local amounts: { number } = GetValuesFromTable(inventory)
```

### `MergeArrays`

Joins any number of arrays, in order, into one new array. The inputs are not changed. It uses generalized iteration, so dictionary entries in an argument are also added (in no defined order).

```luau
function MergeArrays<T>(...: T): { T }
```

Note: the generic is bound to the argument type, so the declared return type is an array of arrays, not an array of elements. You may need to cast the result.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MergeArrays = require(ReplicatedStorage.util.Table.MergeArrays)

local starterItems: { string } = { "Sword", "Shield" }
local bonusItems: { string } = { "Potion" }
local allItems: { string } = MergeArrays(starterItems, bonusItems) :: any
```
