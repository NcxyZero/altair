# Altair - `src/preload` Folder

Rojo syncs this folder as the `ReplicatedFirst` service itself. It holds the client code that must run **before the game fully loads**, such as the loading bootstrap.

---

## 📦 Location

ReplicatedFirst

---

## 📄 Purpose

The `src/preload` folder is used to:

- Contain the **scripts that run first** on the client, such as `Initializer.client.luau`.
- Keep that code in the repository, while Studio-authored `ReplicatedFirst` instances such as `LoadingUI` stay in the place.

---

## 🧠 Behavior in Studio

`default.project.json` maps `src/preload` to `ReplicatedFirst` itself, so the
files in this folder are the root of `ReplicatedFirst`:

- Rojo creates these scripts and overwrites them on every sync, so change them
  in the repository, not in Studio.
- `ReplicatedFirst` sets `$ignoreUnknownInstances: true`, so instances that
  exist only in Studio, such as the `LoadingUI` ScreenGui, survive a sync.
  Author them in Studio and save the place.

---

## ✅ Use Cases

- Preloading UI screens or loading animations.
- Holding modules/scripts needed early in the client lifecycle.
- Caching sound or image assets before a full game load.

---

## 🚦 Loading Bootstrap

`Initializer.client.luau` runs from `ReplicatedFirst` before the rest of the
game has replicated. It has no top-level `ReplicatedStorage` requires:
`ClientData`, `GetBridge`, and TopbarPlus are resolved later with
`WaitForChild` chains or after `game.Loaded`, and every phase runs inside
`xpcall`, so a missing or failing module cannot stop the bootstrap.

1. If `ReplicatedFirst.LoadingUI` is a `ScreenGui` (any hierarchy), a fresh
   clone is put into `PlayerGui` with `ResetOnSpawn = false`, so the first
   character spawn cannot remove it. Only without that template is an existing
   `PlayerGui.LoadingUI` reused (also set to `ResetOnSpawn = false`). The
   loading screen is then enabled, and Roblox's default loading screen is
   removed. While it is shown, the `MainUI` ScreenGuis in `PlayerGui`,
   including copies that replicate later, are disabled and their authored
   `Enabled` values are remembered. Every other `LoadingUI` ScreenGui in
   `PlayerGui` is destroyed at startup, when it arrives while the loading screen
   is shown, and again at the release. Keep `LoadingUI` only in
   `ReplicatedFirst`: a `StarterGui` copy with `ResetOnSpawn = true` is cloned
   again on every respawn after the release, and nothing removes it then.
2. Movement is frozen through the dedicated `LoadingFreezeMovement` action,
   bound at `Enum.ContextActionPriority.High` for every `Enum.PlayerActions`
   item, and the PlayerModule controls are disabled. CoreGui and the TopbarPlus
   bar are hidden. The release frees only that action, but it re-enables the
   PlayerModule controls, CoreGui (except the Backpack) and TopbarPlus. A
   system that changes them during loading must apply its change again after
   the release (`LoadingReleased`) or on `PlayerReady`.
3. The `LoadingUI` assets preload first. After a head start of up to two
   seconds, the background preload waits for `game.Loaded` and for `MainUI` (at
   most 25 seconds), then preloads, in batches of eight, the remaining
   `PlayerGui` assets, then the assets under `ReplicatedStorage.shared.model`
   (if present) and in `SoundService`. Preloading never delays readiness, and
   the first use of a model or a sound does not wait for its assets.
4. The bootstrap waits for `game.Loaded`, then for the player profile (at most
   25 seconds), then for the `ClientBootstrapReady` attribute that
   `src/exec/main.client.luau` sets on the local player as its last step (at
   most 25 seconds; on timeout a warning points at a client controller that may
   be yielding in `Init` or `Start`).
5. The release always runs, even after an error or a timeout: movement and the
   PlayerModule controls are restored (up to five attempts), the gameplay
   ScreenGuis return to their authored state, `LoadingUI` and any other
   `LoadingUI` copy in `PlayerGui` are destroyed, and CoreGui and TopbarPlus
   are shown again with the Backpack kept disabled. As the last step of the
   release, on every path including errors and timeouts, the local player's
   `LoadingReleased` attribute is set to `true`. Code that waits for
   the loading screen should wait for this attribute instead of checking for
   `LoadingUI`.
6. `PlayerReady` fires last, right after `LoadingReleased` is set, on every
   path, including a missing `LoadingUI`, timeouts, and errors. Server flows
   started on `PlayerReady` therefore begin after the loading cleanup and are
   not undone by it.

Without a `LoadingUI`, the movement and CoreGui locks and the readiness waits
still apply; only the loading screen and the `MainUI` hiding are skipped.
