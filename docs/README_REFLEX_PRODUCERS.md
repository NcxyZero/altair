# Reflex Producers in Altair

This document provides an overview of the refactored data handling system in the Altair project, which now uses separate producer files and the `combineProducers` function from the Reflex library.

## Overview

The data handling system has been refactored to:

1. Move producer definitions to separate files in the `shared/reflex` directory
2. Use the `combineProducers` function to combine multiple producers
3. Provide a more modular and maintainable approach to state management

## Producer Files

The following producer files have been created in the `shared/reflex` directory:

### playerProfile.luau

Contains the basic player data such as userId and coins. This is the core player data that doesn't fit into more specific categories.

```luau
-- Example state
local exampleState = {
  userId = 0,
  coins = 0
}

-- Example actions
playerProducer:setCoins(100)
playerProducer:addCoins(50)
```

### gameProfile.luau

Contains game-wide data shared across all clients, such as server start time and active player count.

```luau
-- Example state
local exampleState = {
  serverStartTime = os.time(),
  activePlayers = 0
}

-- Example actions
gameProducer:setActivePlayers(10)
gameProducer:incrementActivePlayers()
gameProducer:decrementActivePlayers()
```

### settingsProfile.luau

Contains player-specific settings such as music volume, SFX volume, UI scale, etc.

```luau
-- Example state
local exampleState = {
  musicVolume = 0.5,
  sfxVolume = 0.5,
  uiScale = 1,
  graphicsQuality = 5,
  showFPS = false
}

-- Example actions
settingsProducer:setMusicVolume(0.8)
settingsProducer:setSFXVolume(0.6)
settingsProducer:toggleFPS()
```

### inventoryProfile.luau

Contains the player's inventory data, including items, equipped items, and inventory slots.

```luau
-- Example state
local exampleState = {
  items = {
    ["item1"] = {
      id = "item1",
      name = "Sword",
      description = "A sharp sword",
      quantity = 1,
      rarity = "common",
      equipped = false
    }
  },
  equippedItems = {
    ["weapon"] = "item1"
  },
  maxSlots = 20
}

-- Example actions
inventoryProducer:addItem("item2", newItem)
inventoryProducer:removeItem("item1")
inventoryProducer:equipItem("item2", "weapon")
```

## Using CombineProducers

The `combineProducers` function from the Reflex library is used to combine multiple producers into a single producer. This allows for a more modular approach to state management while still providing a unified interface.

### Server-Side

In `ServerData.luau`, the producers are combined when a player joins:

```lua
-- Create individual producers
local playerProducer = playerProfile.CreateProducer(data)
local settingsProducer = settingsProfile.CreateProducer(data.settings or settingsProfile.DEFAULT_STATE)
local inventoryProducer = inventoryProfile.CreateProducer(data.inventory or inventoryProfile.DEFAULT_STATE)

-- Combine producers
local combinedProducer = Reflex.combineProducers({
  player = playerProducer,
  settings = settingsProducer,
  inventory = inventoryProducer,
})
```

### Client-Side

In `ClientData.luau`, the producers are combined when player data is loaded:

```lua
-- Create individual producers
local playerProducer = playerProfile.CreateProducer(playerData)
local settingsProducer = settingsProfile.CreateProducer(playerData.settings or settingsProfile.DEFAULT_STATE)
local inventoryProducer = inventoryProfile.CreateProducer(playerData.inventory or inventoryProfile.DEFAULT_STATE)

-- Combine producers
self.playerProducer = Reflex.combineProducers({
  player = playerProducer,
  settings = settingsProducer,
  inventory = inventoryProducer,
})
```

## Accessing Combined State

When using a combined producer, the state is structured according to the producer names used in the `combineProducers` function:

```luau
local combinedState = profile.producer:getState()

-- Access player data
local userId = combinedState.player.userId
local coins = combinedState.player.coins

-- Access settings
local musicVolume = combinedState.settings.musicVolume
local sfxVolume = combinedState.settings.sfxVolume

-- Access inventory
local items = combinedState.inventory.items
local equippedItems = combinedState.inventory.equippedItems
```

## Dispatching Actions

Actions can be dispatched on the combined producer using the format `producerName_actionName` or directly on the individual producers:

```luau
-- Using the combined producer
combinedProducer.player_setCoins(100)
combinedProducer.settings_setMusicVolume(0.8)
combinedProducer.inventory_addItem("item3", newItem)

-- Using individual producers
playerProducer:setCoins(100)
settingsProducer:setMusicVolume(0.8)
inventoryProducer:addItem("item3", newItem)
```

## Saving Data

When saving data to the datastore, the combined state is extracted and restructured:

```luau
-- Extract data from combined state
local playerState = combinedState.player
local settingsState = combinedState.settings
local inventoryState = combinedState.inventory

-- Combine into a single state for saving
local saveableData = {}

for key, value in pairs(playerState) do
  if table.find(SAVE_EXCEPTIONS, key) ~= nil then
    continue
  end

  saveableData[key] = value
end

-- Add settings and inventory
saveableData.settings = settingsState
saveableData.inventory = inventoryState
```

## Benefits of This Approach

1. **Modularity**: Each producer is defined in its own file, making it easier to maintain and extend.
2. **Separation of Concerns**: Each producer is responsible for a specific part of the state.
3. **Reusability**: Producers can be reused in different parts of the application.
4. **Scalability**: New producers can be added without modifying existing code.
5. **Type Safety**: Each producer has its own type definitions, making it easier to catch errors at compile time.
