# Data Handling in Altair

This document provides an overview of the data handling system implemented in the Altair project, based on the approach used in the Helios project.

## Overview

The data handling system consists of two main components:

1. **ServerData** - Manages server-side data, including player profiles and game-wide data
2. **ClientData** - Manages client-side data and mirrors server data on the client

The system uses the following libraries:

- **Reflex** for state management
- **ProfileService** for data persistence
- **Signal** for event handling
- **Promise** for asynchronous operations
- **Bridgenet2** for networking (indirectly through remote events)

## Server-Side Data Handling

The `ServerData` module (`src/server/modules/ServerData.luau`) manages server-side data. It has the following responsibilities:

### Server-Side Player Data Management

- Loading player data from the datastore when a player joins
- Saving player data to the datastore when a player leaves
- Providing access to player data through a producer pattern
- Replicating player data changes to the client

### Persistent Profile Synchronization and Reset

Reflex is the authoritative runtime state. ProfileService autosaves its own
`profileStore.Data`; it does not read the producer automatically.
`ServerData:SyncPlayerProfile(player)` copies the current persistent slices into
that table, applies `SAVE_EXCEPTIONS`, skips invalid top-level UTF-8 strings,
and refreshes the saved `player.lastSeen` without changing the live timestamp.

Synchronization runs after profile initialization, every
`GameConfig.data.playerProfileSyncInterval` seconds (30 by default), and before
departure releases the profile. One server-wide loop handles active profiles
and logs individual synchronization failures. Actual DataStore writes remain
owned by ProfileService. With healthy writes and normal scheduling, a sudden
crash can still lose approximately the synchronization interval plus its
staggered 30-second autosave cycle; DataStore failures can extend that window.

The existing Admin Cmdr command `Reset <players>` calls
`ServerData:ResetPlayerData(player)` to restore every persistent slice to a deep
copy of its own `DEFAULT_STATE`, then synchronizes the profile and kicks each
successfully reset player. `Reset me` resets the executor. Missing profiles are
reported as failures without kicking that player or waiting indefinitely.
The command uses the existing Admin permission hook and automatic command
registration. It does not depend on a `secureResetData` producer action.

### Server-Side Game Data Management

- Managing game-wide data (e.g., server start time, active players)
- Providing access to game data through a producer pattern
- Replicating game data changes to all clients

### Server-Specific Remote Communication

The module sets up the following remote events and functions for communication with clients:

- `ReplicateStore` - For server-to-client player changes and explicitly registered client preference actions
- `ReplicateGameStore` - For server-to-client game data changes
- `GetPlayerData` - For clients to get their player data
- `GetGameData` - For clients to get game data

## Client-Side Data Handling

The `ClientData` module (`src/client/modules/ClientData.luau`) manages client-side data. It has the following responsibilities:

### Client-Side Player Data Management

- Loading player data from the server
- Mirroring server-side player data
- Providing access to player data through a producer pattern
- Requesting explicitly registered preference changes from the server

### Client-Side Game Data Management

- Loading game data from the server
- Mirroring server-side game data
- Providing access to game data through a producer pattern
- Applying server-originated game data changes locally

Global replication received while `GetGameData` is loading is queued and
replayed in order after the initial snapshot, before `gameDataLoadedSignal`
fires. The remote subscriptions belong to the controller's `Maid`.

### Client-Specific Data Management

- Managing client-specific data (e.g., local settings)
- Providing access to client-specific data through a producer pattern

## Usage Examples

### Server-Side

```luau
-- Get a player's profile
local profile = ServerData:GetPlayerProfile(player)

-- Wait for a player's profile to be loaded
local profileYielded = ServerData:WaitForPlayerProfile(player):expect()

-- Wait for a player's profile.producer to be loaded
ServerData:GetPlayerProducerAsync(player):andThen(function(producer)
    -- Use producer
    local coins = producer:getState().coins
    print("Player has", coins, "coins")

    -- Modify profile data
    producer.addCoins(100)
end)

-- Access game data
local activePlayers = ServerData.gameProducer:getState().activePlayers
print("Active players:", activePlayers)

-- Modify game data
ServerData.gameProducer:setActivePlayers(10)
```

### Client-Side

```luau
-- Get player data
ClientData:GetPlayerProducerAsync():andThen(function(producer)
    -- Read authoritative player data
    local money = producer:getState().player.money
    print("I have", money)

    -- Registered preference setters are validated again by the server
    producer.setMusicVolume(0.8)
end)

-- Get game data
ClientData:GetGameProducerAsync():andThen(function(producer)
    -- Use game data
    local activePlayers = producer:getState().activePlayers
    print("Active players:", activePlayers)

    -- Cannot modify game data by client
end)

-- Access client-specific data [WIP]
local musicVolume = ClientData.clientProducer:getState().localSettings.musicVolume
print("Music volume:", musicVolume)

-- Modify client-specific data
ClientData.clientProducer.setLocalSetting("musicVolume", 0.8)
```

## Data Flow

1. When a player joins, the server loads their data from the datastore
2. The server creates a producer for the player's data
3. The client requests the player's data from the server
4. The client creates a producer for the player's data
5. Server actions replicate to the client
6. Registered client preference actions are validated and applied by the server
7. The server periodically synchronizes persistent producer state into ProfileService data for autosave
8. When a player leaves, the server synchronizes their latest state and releases the profile for its final save

## Security Considerations

- Client-originated actions are denied unless a profile exports them through `CLIENT_ACTIONS`
- Every registered action validates its argument count, types, and allowed ranges on the server
- Prefixes such as `secure` are naming conventions, not authorization controls
- Gameplay, inventory, progression, and monetization changes use dedicated server-validated bridges
- The game producer is read-only on clients and has no client-to-server replication handler
- The server handles data persistence, ensuring data is saved properly

## Implementation Details

### Server-Side Implementation

The `ServerData` module is implemented as a controller in the Altair project's module system. It has the following key components:

- `profiles` - A table mapping players to their profiles
- `gameProducer` - A producer for game-wide data
- `playerDataLoadedEvent` - A signal fired when a player's data is loaded
- `GetPlayerProfile` - A function to get a player's profile
- `WaitForPlayerProfile` - A function to wait for a player's profile to be loaded
- `GetPlayerProducerAsync` - A function to get the player producer asynchronously
- `GetGameProducerAsync` - A function to get the game producer asynchronously
- `SyncPlayerProfile` - Copies current persistent state into ProfileService data
- `ResetPlayerData` - Resets every persistent slice and synchronizes the active profile
- `PlayerAdded` - A function called when a player joins
- `PlayerRemoving` - A function called when a player leaves
- `Init` - A function called when the module is initialized

### Client-Side Implementation

The `ClientData` module is implemented as a controller in the Altair project's module system. It has the following key components:

- `playerProducer` - A producer for player data
- `gameProducer` - A producer for game data
- `clientProducer` - A producer for client-specific data
- `isPlayerDataLoaded` - A boolean indicating if player data is loaded
- `isGameDataLoaded` - A boolean indicating if game data is loaded
- `playerDataLoadedSignal` - A signal fired when player data is loaded
- `gameDataLoadedSignal` - A signal fired when game data is loaded
- `GetPlayerProducerAsync` - A function to get the player producer asynchronously
- `GetGameProducerAsync` - A function to get the game producer asynchronously
- `PlayerAdded` - A function called when a player joins
- `Init` - A function called when the module is initialized
