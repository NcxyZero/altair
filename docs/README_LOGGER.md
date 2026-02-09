# Altair - `Logger` Utility

The `Logger` module provides safe debug-only logging functions designed for use exclusively in **Studio mode**. It ensures that logging code does not run in live production environments.

---

## 📦 Location

`ReplicatedStorage.util.Logger`

---

## 🧠 Behavior

All logging functions are disabled outside Roblox Studio. They will **do nothing in live game sessions** to prevent exposing sensitive debug information.

The logger automatically prefixes each message with the calling file (and line when available). Do **not** manually add source labels in your strings (for example `"[GameController]"`); this makes logs noisy and redundant.

## 🔐 Usage

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(ReplicatedStorage.util.Logger)

Logger.print("Example print")
Logger.warn("Example warn")
Logger.assert(game.PlaceId == 0, "Example assert")
Logger.error("Example error")
```
