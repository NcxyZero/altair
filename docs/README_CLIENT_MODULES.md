# Altair - `main.client.luau` Documentation

This script handles the core client-side initialization for the Altair Roblox project using Luau and Rojo. It dynamically loads modules from the `modules` folder, connects tag-based behavior using `CollectionService`, and manages per-frame logic and player events.

---

## 📁 Module Folder Structure

The `modules` folder can contain the following module types, auto-detected by naming convention or the `type` field:

- `controller` – logic modules initialized on the client, supporting lifecycle callbacks.
- `module` – standard shared utility modules.
- `tag` – modules bound to instances tagged via `CollectionService`.
- `local_tag` – similar to `tag`, but filtered for instances relevant only to the local player.

---

## ⚙️ Initialization Flow

1. All non-template modules from `modules` are loaded.
2. Each module is categorized by its `type` (default: `module`).
3. Controllers with an `index` field are loaded first (`loadFirst`), then others.
4. Tag modules are connected to instance-added/removed signals.
5. Player and character lifecycle events are connected.
6. Runtime frame-based updates (`Heartbeat`, `Stepped`, `Render`) are routed.

---

## 🧩 Supported Lifecycle Callbacks

Controllers and tag classes may implement the following optional methods:

- `Init(self)` — Called once during initialization.
- `PlayerAdded(self, player: Player)`
- `CharacterAdded(self, character: Model)` _(for local player only)_
- `CharacterAppearanceLoaded(self, character: Model)` _(for local player only)_
- `AnyCharacterAdded(self, player: Player, character: Model)`
- `AnyCharacterAppearanceLoaded(self, player: Player, character: Model)`
- `Died(self, character: Model)` _(for local player only)_
- `AnyDied(self, player: Player, character: Model)`
- `Physics(self, deltaTime: number)` — Called every frame on `Heartbeat`.
- `Stepped(self, deltaTime: number)` — Called every frame on `PreSimulation`.
- `Render(self, deltaTime: number)` — Called every frame on `PreRender`.

---

## 🏷️ Tag Behavior

Tags are connected using `CollectionService`:

- `tag` modules respond globally.
- `local_tag` modules only react to instances belonging to the local player or their character.
- When an instance with the specified tag is added, the module's `new(instance)` function is called and stored.
- When removed, if the class instance has a `Destroy()` method, it is called.

---

## 🧠 GUI Behavior

All `ScreenGui` instances in `PlayerGui` have `ResetOnSpawn` set to `false` unless they have a custom attribute `SkipResetOnSpawn`.

---

## 🔄 Runtime Event Hooks

- `Players.PlayerAdded` and `CharacterAdded`
- `CharacterAppearanceLoaded`
- `Humanoid.Died`
- `RunService.Heartbeat`
- `RunService.PreSimulation`
- `RunService.PreRender`
- `PlayerGui.ChildAdded`

---

## 📌 Notes

- Modules containing the word `"template"` in their name are ignored.
- Errors in requiring a module are silently caught via `pcall`.
- Module references are stored in the `path` table based on type.

---
