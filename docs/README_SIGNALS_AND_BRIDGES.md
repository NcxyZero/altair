# Altair — Network Utilities (`ReplicatedStorage.util`)

This module group provides reusable networking utilities for the **Altair** project, designed to simplify bridge and signal access across client and server

---

## 🔌 `GetBridge.luau`

### 📄 Description

Returns a cached instance of a `BridgeNet2` bridge (server or client) by name. Ensures bridges are reused throughout the game.

### 📦 Location

`ReplicatedStorage.util.GetBridge`

### ✅ Usage

## Signal

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetSignal = require(ReplicatedStorage.util.GetSignal)

local mySignal = GetSignal("MySignal")
mySignal:Fire("Hello, World!")

mySignal:Connect(function(message: string)
    print(message)
end)
```

## Bridge Client

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetBridge = require(ReplicatedStorage.util.GetBridge)

local myBridge = GetBridge("MyBridge")

myBridge.OnClientEvent:Connect(function(message: string)
    print(message)
end)

myBridge:Fire("Hello, World!")
```

## Bridge Server

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetBridge = require(ReplicatedStorage.util.GetBridge)

local myBridge = GetBridge("MyBridge")

myBridge.OnServerEvent:Connect(function(player: Player, message: string)
    myBridge:Fire(player, message)
    print(message)
end)
```

### IMPORTANT NOTE

As for now do not use `InvokeServerAsync()` as it may break the game, instead use two `Connect()` and yield or use Roblox remote functions if needed
