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

The Admin commands `AddRebirths`, `SetRebirths`, and `SubtractRebirths` take
`<players> <amount>` with a non-negative whole amount. Subtraction clamps at
`0`, and every change goes through the server-owned `secureAddRebirth`,
`secureSetRebirth`, and `secureSubtractRebirth` player profile actions.

The same persistence and reset flow covers `settings`, `inventory`, `player`,
and `monetization` discovered from this project's own profile modules.
`settingsProfile.CLIENT_ACTIONS` registers the supported preference setters
and their validators. Game-specific preferences and progression profiles belong
to each game rather than to this data layer.
Monetization grants clone their nested ownership tables before updating them;
an existing offer with value `false` is a configured, unowned offer and can be
granted without enabling arbitrary offer creation.

Game passes are granted only when the purchase prompt reports a purchase, and a
pass the profile already owns is not prompted again. A pass named `VIP` also
sets the `IsVIP` player attribute. Game-pass grants synchronize the profile
immediately. Before a developer product is prompted, the server refuses it when
one of its offers is already owned or is not declared in the monetization
profile's `offers`, unless `GameConfig.core.monetizationOfferCreationAllowed` is
enabled. An owned pass or offer is refused with a "You already own this!"
notification. The server accepts one `MonetizationPrompt` request per player
every 0.75 seconds, and `MonetizationButton`, `MonetizationPrompt`, and
`RaycastActions` share the 1-second client cooldown `PromptPurchase`.

`ProcessReceipt` grants synchronously. It waits for the buyer's profile, runs
the product's execs with `(player, data, config, receiptInfo)`, grants its
offers, and synchronizes the profile. Each granted offer runs its
`MonetizationExecs.offers[offerName]` hook with
`(player, offerName, receiptInfo)`; an offer granted by a redeem code runs the
same hook with `receiptInfo = nil`. Products configured as a plain ID and as a
table are both supported. It returns `NotProcessedYet`, so Roblox retries the
receipt later, when the buyer leaves before the profile loads, the product is
unknown, an offer is not declared, an exec errors or returns `false`, or the
profile cannot be synchronized after the grant. An exec name missing from
`MonetizationExecs.execs` is skipped with a warning. After every exec and offer
succeeded, the receipt's `PurchaseId` is added to `monetization.purchaseIds`
(the last 50 granted receipts) in the same profile synchronization as the
grant; any failure returns `NotProcessedYet`. Roblox never delivers an
acknowledged receipt again, so `PurchaseGranted` waits for the DataStore: the
`PurchaseId` is also added to the profile's ProfileService MetaTag
`purchaseIds` (the last 50), an early profile save is requested, and
`ProcessReceipt` yields until `MetaData.MetaTagsLatest` shows a save that holds
it (usually a few seconds; longer while DataStore writes fail). When the
profile is released first, for example because the buyer left, it returns
`NotProcessedYet` and Roblox delivers the receipt again later. A re-delivered
receipt whose `PurchaseId` is already in either list is acknowledged, once
saved, without granting again, on any server, and concurrent deliveries of one
receipt on a server get `NotProcessedYet` while the first one is granted or
waits. A rejected receipt is retried in full, so an exec that can return
`false` must do so before granting anything: the execs listed before it run
again. `Reset` clears `monetization.purchaseIds` with the rest of the slice but
keeps the MetaTag, so a reset does not grant a pending receipt twice.

Prompt limited products and products with offers through `ServerMonetization`,
which `MonetizationButton`, `MonetizationPrompt`, and `RaycastActions` reach
through the `MonetizationPrompt` bridge. `BuyDevProduct` prompts raw product IDs
from the client and skips the offer checks and the stock reservation; a limited
product bought that way takes its stock unit only when its receipt is granted.

### Built-In Profile Fields

Besides `userId`, `lastSeen`, `money`, and `rebirth`, the player profile keeps:

- `tutorialCompleted` (default `false`) and `tutorialStep` (default `1`): a
  generic tutorial state. `secureRestartTutorial()` resets both;
  `secureCompleteTutorial()` sets `tutorialCompleted = true` and keeps the step.
  A game that advances steps adds its own setter. Existing saves receive these
  defaults through ProfileService reconciliation, so returning players start
  with `tutorialCompleted = false`; add a migration before gating content on it.
- `redeemedCodes`: a map from each redeemed code to its Unix timestamp, written
  by `secureRedeemCode(code, timestamp)`, which ignores empty and
  already-redeemed codes. `RedeemCodeController` owns this flow.
- `rebirth`: `secureAddRebirth(amount?)` adds `1` without an amount, rounds other
  amounts down, ignores amounts that are not positive, and caps the total at
  2^53 - 1.
- `money`: `secureAddMoney` and `secureSpendMoney` leave the balance unchanged
  when the new total is not a finite number.

Never add a player field named exactly `tutorial`: `ServerData` discards the
loaded profile data when `data.player.tutorial` exists.

The settings profile also stores `clickRippleEnabled` (default `true`),
`hideOtherPlayers` (`false`), `mapDetailsEnabled` (`true`), and
`shadowsEnabled` (`true`). Their setters (`setClickRippleEnabled`,
`setHideOtherPlayers`, `setMapDetailsEnabled`, `setShadowsEnabled`) are
registered in `CLIENT_ACTIONS` and accept only booleans. `SettingsUI` applies
them on the client.

The game profile replicates `limitedItems`, the remaining stock of each limited
product by its `itemKey`. Only `LimitedStockController` writes it, through
`secureSetStock(itemKey, amount)`, which stores the amount rounded down with a
minimum of `0`. `GameConfig.game.limitedItems` is keyed by the
`MonetizationConfig` product name, and each entry also declares `amount` and
`stockName`; see [Server Modules](README_SERVER_MODULES.md).

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
    local money = producer:getState().player.money
    print("Player has", money, "money")

    -- Modify profile data (Reflex actions are called with a dot, not a colon)
    producer.secureAddMoney(100)
end)

-- Access game data
local activePlayers = ServerData.gameProducer:getState().activePlayers
print("Active players:", activePlayers)

-- Modify game data
ServerData.gameProducer.setActivePlayers(10)
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
