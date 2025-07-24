# Altair - `Logger` Utility

The `Logger` module provides safe debug-only logging functions designed for use exclusively in **Studio mode**. It ensures that logging code does not run in live production environments.

---

## 📦 Location
`ReplicatedStorage.util.Logger`

---

## 🧠 Behavior

All logging functions are disabled outside of Roblox Studio. They will **do nothing in live game sessions** to prevent exposing sensitive debug information.

## 🔐 Usage

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(ReplicatedStorage.util.Logger)

Logger.print("Example print")
Logger.warn("Example warn")
Logger.assert(game.PlaceId == 0, "Example assert")
Logger.error("Example error")
```
