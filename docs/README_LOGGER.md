# Altair - `Logger` Utility

The `Logger` module provides debug logging gated by `GameConfig.debug`, designed for use exclusively in **Studio mode**. It ensures that logging code does not run in live production environments.

---

## 📦 Location

`ReplicatedStorage.util.Core.Logger`

---

## 🧠 Behavior

`GameConfig.debug.loggerShowInStudio` (default `true`) enables logging in Studio. Outside Studio, logging functions currently do nothing: `emit()` and `assert()` also return early when not in Studio, so `loggerShowInGame` (default `false`) has no effect until that guard is removed. This prevents exposing sensitive debug information in live game sessions.

The logger automatically prefixes each message with the calling file (and line when available). Do **not** manually add source labels in your strings (for example `"[GameController]"`); this makes logs noisy and redundant.

## 🔐 Usage

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(ReplicatedStorage.util.Core.Logger)

Logger.print("Example print")
Logger.warn("Example warn")
Logger.assert(game.PlaceId == 0, "Example assert")
Logger.error("Example error")
```

## On-screen developer log

`DevLogger` (`src/client/ui/DevLogger.luau`) mirrors client warnings and errors
(`MessageWarning` and `MessageError`) into an on-screen `DevLogDisplay`
ScreenGui; `print` and `Logger.print` output does not appear there. Anyone testing in Studio, the owner of a
user-owned experience, and the user IDs in `GameConfig.cmdr.players` can use it.
Other players need at least the rank of the `GameConfig.roles` entry named by
`GameConfig.debug.onScreenOutputMinRole` (`admin` by default), checked in that
role's `groupId` or, when it is unset, in the group that owns the experience.
Failed rank lookups deny access. The display retains at most
`onScreenOutputMaxLines` messages (`5` by default). The
`workspace.SHOW_DEV_LOGS = false` attribute disables it entirely.

Default visibility is controlled separately from access: `onScreenOutputShowInStudio`
defaults to `true`, `onScreenOutputShowInGame` to `false`, and
`onScreenOutputShowOnMobile` to `false`. Mobile starts hidden even when the
Studio or game setting is enabled, unless the mobile option is also enabled.
Authorized players can toggle the display with `=` or `/devlog` regardless of
its default visibility.
