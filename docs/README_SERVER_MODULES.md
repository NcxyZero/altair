# Altair - `main.server.luau` Documentation

This script handles the **server-side initialization** logic for the Altair project built using Roblox + Rojo. It dynamically loads and manages controllers, modules, and tag-based logic. It also handles per-frame logic (`Heartbeat`, `PreSimulation`, `PreRender`) and player/character lifecycle events.

---

## 📁 Module Folder Structure

Modules are loaded from the `modules` folder and categorized based on the `.type` field:

- `controller` – Core server-side logic that reacts to player and game events.
- `module` – Generic modules/utilities.
- `other` – Shared singleton utilities that may opt into `PlayerRemoving`.
- `tag` – Tag-bound modules initialized via `CollectionService`.

Modules with `"template"` in their name are ignored.

---

## ⚙️ Initialization Flow

1. Each module is `require()`'d and assigned based on its `type`.
2. Controllers with `.index` are queued to `loadFirst` for priority loading.
3. All controllers are initialized via the `Init(self)` method if available.
4. If a controller has `PlayerAdded(self, player)` defined, it is called for existing players.
5. Tagged modules (`tag`) are initialized for existing tagged instances and listen for new ones.

---

## 🧩 Supported Lifecycle Callbacks

Modules and tag classes may define any of the following optional functions:

- `Init(self)` — Called once at startup.
- `PlayerAdded(self, player)`
- `CharacterAdded(self, player, character)`
- `CharacterAppearanceLoaded(self, player, character)`
- `Died(self, player, character)`
- `Physics(self, deltaTime)` — Per-frame logic (`Heartbeat`)
- `Stepped(self, deltaTime)` — Physics step (`PreSimulation`)
- `Render(self, deltaTime)` — Rendering step (`PreRender`)

---

## 🏷️ Tag Behavior

Tags are handled via `CollectionService`.

For each `tag` module:

- Must define `.tag` and `.new(instance)` returning a class.
- When a tagged instance is added:
  - `new(instance)` is called.
  - If `.PlayerAdded` exists in the module, it runs for all current players.
- When a tagged instance is removed:
  - `.Destroy()` is called if it exists.

All tagged instances are initialized at startup.

---

## 👤 Player Lifecycle Events

The system listens to:

- `Players.PlayerAdded`
- `CharacterAdded`
- `CharacterAppearanceLoaded`
- `Humanoid.Died`

For each event, the system calls matching lifecycle methods in all controllers and tag classes (if implemented).

Server-side singleton utilities with `type = "other"` receive
`PlayerRemoving(self, player)` when implemented. This is intentionally limited
to player cleanup; other lifecycle callbacks remain controller/tag contracts.

`CacheManager`, `QueueManager`, `CooldownManager`, and `Conditions` each share
one implementation table between their server and client interfaces. Internal
methods take `player: Player?`; server calls pass the player directly, while
the typed `WithoutPlayer` adapter inserts `nil` for client calls. Adapters are
created when the module loads and preserve optional arguments and return values.
Public server/client signatures and their exported intersection types remain
unchanged. Mutable state belongs to each interface, not its shared method table;
server state stays isolated per player, with `PlayerRemoving` on the server only.

`ObjectPoolManager` is shared by server and client. `Acquire` reuses a free
instance or creates one from the registered template/factory when exhausted;
`Size` counts only free instances. An unregistered pool cannot create instances.
`Clear` and `ClearAll` destroy free instances and remove registrations, while
leaving templates and checked-out instances under the caller's ownership.
`Register` replaces an existing pool and destroys its old free instances.
Return each acquired instance exactly once to its original key/category before
clearing or replacing that pool; destroy any still checked-out instances yourself.

---

## 🔄 Runtime Event Hooks

The following per-frame events are supported and executed using `task.defer`:

- `RunService.Heartbeat → .Physics(deltaTime)`
- `RunService.PreSimulation → .Stepped(deltaTime)`
- `RunService.PreRender → .Render(deltaTime)`

These allow modules to hook into Roblox's simulation/update loop.

---

## 📝 Notes

- Module loading errors are caught using `pcall`.
- Each module is stored in `path[moduleType][moduleName]`.
- Class instances for tagged objects are cached in a `tags` table.

---
