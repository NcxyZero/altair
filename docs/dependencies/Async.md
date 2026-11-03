# Async

Promise-based helpers: wrap a function so it returns a `Promise`, and wait for tagged instances, Reflex producer changes or a client/server bridge handshake.

## Installation

```bash
bash require-dependency.sh Async
```

```powershell
.\require-dependency.ps1 Async
```

Installed into `src/util/Async`, required as `ReplicatedStorage.util.Async.<Module>`.

## Requirements

- Wally packages: `Maid`, `Promise`, `Reflex`
- Core utils: `GetBridge`
- Other packages: none

## Modules

### `Async`

Higher-order function: returns a wrapper that, when called, runs `callback` with the same arguments inside `Promise.new` and `xpcall`. The promise resolves with the callback's first return value; on error the error is printed through `warn` (the `xpcall` handler) and the promise rejects.

```luau
Async(callback: (A...) -> T...): (A...) -> Promise.TypedPromise<any>
```

Notes: only the first return value is kept. The rejection value is the return of `warn`, i.e. `nil`, not the error message. Arguments are re-packed with `{ ... }` and `unpack`, so trailing `nil` arguments are dropped.

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Async = require(ReplicatedStorage.util.Async.Async)

local getPlayerName: (number) -> any = Async(function(userId: number): string
  return Players:GetNameFromUserIdAsync(userId)
end)

getPlayerName(1):andThen(function(name: string): ()
  print(name)
end)
```

### `WaitForElement`

Polls with `task.wait(waitCooldown)` while `element` is falsy and returns it; when `maxRetries` is given, it warns and prints a traceback once the retry count reaches it, but keeps waiting.

```luau
WaitForElement(element: T, maxRetries: number?, waitCooldown: number?): T
```

Note: `element` is a value, not a getter, so it is never re-evaluated: a truthy value returns immediately and a `nil` value loops forever. It is only useful for values that cannot change while waiting; prefer `WaitForChild` or a promise helper.

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaitForElement = require(ReplicatedStorage.util.Async.WaitForElement)

local player: Player = WaitForElement(Players.LocalPlayer, 10, 0.1)
```

### `WaitForProducerChange`

Returns a `Promise` that resolves (with no value) the first time the slice selected by `getSlice` changes on the given Reflex `producer`. It subscribes with `producer:subscribe(getSlice, ...)` and unsubscribes when it fires; the current value does not count, only a later change.

```luau
WaitForProducerChange(producer: Reflex.Producer<any, any>, getSlice: (state: State) -> Comparison): Promise.Promise
```

Note: cancelling the promise does not unsubscribe; the subscription stays until the slice changes.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientData = require(ReplicatedStorage.client.modules.ClientData)
local Reflex = require(ReplicatedStorage.package.Reflex)
local WaitForProducerChange = require(ReplicatedStorage.util.Async.WaitForProducerChange)

local producer: Reflex.Producer<any, any> = ClientData:GetPlayerProducerAsync():expect()

WaitForProducerChange(producer, function(state: any): number
  return state.player.rebirth
end):andThen(function(): ()
  print("Rebirth changed")
end)
```

### `WaitForRespond`

Server-to-client handshake over the `WaitForRespond` bridge from `GetBridge` (created when the module is required, which yields on the client). The server must require `WaitForRespond` during startup, for example at the top of a server module, or the client's request for the bridge is not confirmed and its bridge sends and receives nothing. On the server, `Wait(id, player)` connects to the bridge, yields (polling with `task.wait`) until that player fires `id`, then fires `id` back to the player as an acknowledgement. `Respond(id, player?)` fires `id` to `player` on the server, or to the server from the client.

```luau
WaitForRespond:Wait(id: string, player: Player): ()
WaitForRespond:Respond(id: string, player: Player?): ()
```

Notes:

- Only the server side of `Wait` works. On the client the bridge callback receives the content as its first argument, so `sentId` is `nil` and never matches, and `Remote` would also concatenate a `nil` player id; a client `Wait` never returns.
- A `Respond` fired before the server's `Wait` connects is lost, and `Wait` has no timeout.

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaitForRespond = require(ReplicatedStorage.util.Async.WaitForRespond)

Players.PlayerAdded:Connect(function(player: Player): ()
  WaitForRespond:Wait("ClientReady", player)

  print(`{player.Name} is ready`)
end)
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaitForRespond = require(ReplicatedStorage.util.Async.WaitForRespond)

WaitForRespond:Respond("ClientReady")
```

### `WaitForTagged`

Returns a `Promise` resolving with the first instance tagged `desiredTag` (via `CollectionService`), optionally filtered with `IsA(className)`. Existing tagged instances are checked first; otherwise it waits on `GetInstanceAddedSignal`. Cancelling the promise disconnects the listener.

```luau
WaitForTagged(desiredTag: string, className: string): Promise.TypedPromise<T>
```

Note: `className` is typed as required, but passing `nil` is handled (any class is accepted). There is no timeout; chain `:timeout()` if needed.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaitForTagged = require(ReplicatedStorage.util.Async.WaitForTagged)

WaitForTagged("SpawnLocation", "BasePart"):timeout(10):andThen(function(spawnPart: BasePart): ()
  print(spawnPart:GetFullName())
end)
```

### `WaitForTaggedDescendant`

Same as `WaitForTagged`, but only accepts instances that are descendants of `ancestor`; `className` is optional. Existing tagged instances are checked first, then `GetInstanceAddedSignal`; cancelling disconnects the listener.

```luau
WaitForTaggedDescendant(ancestor: Instance, desiredTag: string, className: string?): Promise.TypedPromise<T>
```

Note: an instance that is tagged before being parented under `ancestor` is missed, because the descendant check runs only when the tag is added.

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaitForTaggedDescendant = require(ReplicatedStorage.util.Async.WaitForTaggedDescendant)

local character: Model = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()

WaitForTaggedDescendant(character, "Weapon", "Tool"):andThen(function(tool: Tool): ()
  print(tool.Name)
end)
```
