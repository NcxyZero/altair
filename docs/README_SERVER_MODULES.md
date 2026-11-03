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

1. Every non-template `ModuleScript` in the `ServerScriptService.server` folders
   and in `ReplicatedStorage.shared.modules` is `require()`'d and assigned based
   on its `type`. `ServerInitConfig` lists top-level server folders or
   individual module names that the initializer skips (`serverConfig` by
   default).
2. Controllers with a numeric `.index` are queued to `loadFirst` and initialized
   first in ascending order (ties sorted by module name), then the others.
3. All controllers are initialized via the `Init(self)` method if available. An
   `Init` that runs longer than 5 seconds logs a warning, and the next
   controller starts while it finishes.
4. `Players.PlayerAdded` and `PlayerRemoving` are connected before the first
   `Init`. Each controller gets `PlayerAdded(self, player)` exactly once per
   player, in its own thread: right after its `Init` for players already in the
   game, and on join for later players, including players who join while
   startup still runs.
5. Tagged modules (`tag`) are initialized for existing tagged instances and listen for new ones.
6. `Start(self)` runs for every controller in the same order; a yielding `Start`
   delays the controllers after it.

Only the server creates bridges. Create every bridge that clients use with
`GetBridge` or `GetFunctionBridge` during startup (at the top of a server
module, in `Init` or in `Start`), never lazily later: a client's request for a
bridge name is answered only for names the server has created, and a request
made while startup still runs waits for it to end (at most 30 seconds). The
server accepts string names of 1 to 100 characters and at most 200 requests per
player every 10 seconds. A client whose name is not confirmed logs a warning
and gets a bridge that sends and receives nothing (with Bridgenet2 an inert
Bifrost bridge, because a Bridgenet2 client bridge would wait for the server
forever); invoking an unconfirmed function bridge errors. The bootstrap itself
creates `CharacterScale`, `TeleportToBase` and `TeleportToTag`
(`CLIENT_ONLY_BRIDGE_NAMES`), the bridges of client modules Altair ships without
a server half; nothing listens to them until a game connects its own handler.

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

For each event, the system calls the matching lifecycle method on every
controller that has received `PlayerAdded` for that player, and on all tag
classes (if implemented). `PlayerRemoving` also reaches only the controllers
that received the player, plus every `other` module and tag class.

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

## 🧰 Bundled Server Modules

These controllers ship with Altair. Each one stays inert until its
configuration or client counterpart is used. `AntiKickController` and
`FriendBoostController` do nothing unless `GameConfig.game.antiKick.enabled` or
`GameConfig.game.friendBoostEnabled` is `true` (default `false`).

### `AntiKickController`

Rejoins idle players before Roblox's 20-minute idle kick. Does nothing on the
client and the server unless `GameConfig.game.antiKick.enabled` is `true`
(default `false`); while it is disabled, `GetResumeCFrame` returns `nil`. The
client half fires the `AntiIdleRejoin` bridge once `LocalPlayer.Idled` reports
`GameConfig.game.antiKick.idleSeconds` (19 minutes by default). The server
ignores requests within `requestCooldown` seconds or while a teleport is pending,
synchronizes the profile with `ServerData:SyncPlayerProfile`, and teleports the
player to a random non-full public server of the same place, or to the same
server in a private server. The server list is read with `HttpService` from
`games.roproxy.com`, so **Allow HTTP Requests** must be enabled. Without a
server ID, it teleports to any server of the place. A targeted teleport that
fails, either because `TeleportAsync` throws or later through
`TeleportInitFailed` (for example a full server), gets one more try with any
server of the place; after a `Flooded` result it waits 15 seconds first.
Teleport data carries the character's position and facing, and `PlayerAdded`
restores them for players arriving from the same place;
`GetResumeCFrame(player)` lets spawn logic skip its own placement. Studio skips
the teleport, and teleports only work in published places.

Reserved servers (`PrivateServerId ~= ""` and `PrivateServerOwnerId == 0`) are
skipped on the client and the server, because they only take players with their
access code; idle players there are kicked as usual. In a VIP server the rejoin
targets the same server (`ServerInstanceId = JobId`), which has not been
checked in a live server.

### `FriendBoostController`

Counts each player's friends on the same server with
`Player:IsFriendsWithAsync` (index 2). Does nothing on the client and the
server unless `GameConfig.game.friendBoostEnabled` is `true` (default `false`);
while it is disabled, `FriendsInServer` and `FriendBoostPercent` are never set
and `GetBoostMultiplier` returns 1. Pair checks share a server-wide token
bucket (`GameConfig.game.friendBoostApiRequestsPerMinute` and
`friendBoostApiBurstCapacity`), are cached for `friendBoostPairCacheDuration`
seconds, are deduplicated while in flight, and wait in a queue while the budget
is exhausted. A leaving player's pairs are removed immediately. The controller
sets the `FriendsInServer` and `FriendBoostPercent` player attributes
(friends × `friendBoostPercentPerFriend`), and `GetBoostMultiplier(player)`
returns `1 + FriendBoostPercent / 100`. Nothing applies the multiplier
automatically; reward code multiplies its own grants. Client `FriendBoost`
refresh requests, sent when Roblox reports a new or removed friendship, must
name another player in the server by a whole-number `userId`. A request within
a player's `friendBoostClientRefreshCooldown` waits in the shared queue instead
of being dropped.

### `LimitedStockController`

Sells developer products from a stock shared by every server (index 1). Each
`GameConfig.game.limitedItems` entry is keyed by the `MonetizationConfig`
product name and declares `amount` (the total stock), `itemKey` (the key
replicated in `gameProfile.limitedItems`) and `stockName` (part of the key
`remaining::<stockName>::<itemKey>` in the `GlobalStockRemaining_v1` DataStore;
a new name starts a fresh stock). With the default empty table the controller
stays idle, without a MessagingService subscription or polling. Otherwise it
writes the full `amount` into every missing remaining counter (a failed
DataStore read replicates nothing, so clients keep showing `...`), refreshes it
every 15 seconds, and asks other servers to refresh through the
`AltairLimitedStock_v1` MessagingService topic.

`ServerMonetization` reserves one unit with `ReserveProduct` before prompting a
limited product and notifies the player when the item is sold out, another
purchase is pending, or the stock is unavailable. A completed prompt commits the
reservation, a cancelled one restores the unit, and `ProcessReceipt` calls
`CompletePurchase` after a successful grant. Leaving players release their
unconfirmed reservation. A confirmed reservation keeps its unit, and the server
remembers it so the retried receipt does not take another (a retry on a
different server takes one more unit). When `CompletePurchase` finds neither,
for example for a purchase prompted outside `ServerMonetization`, it takes a
unit in the background after the grant and logs an oversell when the stock is
empty; the receipt is granted either way. Clients read the remaining counts
from `gameProfile.limitedItems[itemKey]`. Prompt limited products through
`ServerMonetization`; `BuyDevProduct` prompts raw product IDs and skips the
reservation, so its purchase can oversell a sold-out item (the oversell is
logged).

### `RedeemCodeController`

Redeems codes sent through the `RedeemCode` bridge, for example by the `Codes`
block of `ShopUI`. Input longer than 64 characters is rejected before it is
trimmed and upper-cased; the code is limited to 32 characters and one request
per 0.75 seconds per player, and looked up in `RedeemCodeConfig.rewards`
(`src/shared/config/RedeemCodeConfig.luau`, empty by default; keys must be upper
case). A reward is `{ money: number, offerName: string? }`. Codes already
stored in `player.redeemedCodes` and players whose profile is still loading are
rejected. A successful redeem records the code with `secureRedeemCode`, grants
`secureAddMoney` and the offer through `ServerMonetization:GrantOffer`, which
also runs its `MonetizationExecs.offers` hook with `receiptInfo = nil`,
synchronizes the profile, and replies through the `Notification` bridge with
`RedeemCodeConfig.successColor` or `errorColor`. An `offerName` must already be declared in the monetization
profile's offers unless `GameConfig.core.monetizationOfferCreationAllowed` is
enabled; otherwise the code is rejected without being used up.

### `PlayerObservationController`

Implements the Admin commands `spectate <player> [keepHUD]` and `unspectate`
(index 2). `SetSpectate(observer, target, keepHUD)` sets the observer's
`SpectateUserId` and `SpectateKeepHUD` attributes, which the client
`FocusController` follows (see [Client Modules](README_CLIENT_MODULES.md)).
Choosing yourself or no target restores your camera. While spectating, the
target's `HumanoidRootPart` is added as a replication focus of the observer, so
spectating works with StreamingEnabled; the focus follows respawns and is
cleared when either player leaves.

### `ServerCmdr`

Registers Cmdr's hooks from `src/server/cmdr/hooks` first (including the
`BeforeRun` permission check), then the types from `src/server/cmdr/types`,
Cmdr's default commands and the commands from `src/server/cmdr/commands`. Then,
also after a failed registration, it sets the attribute `Registered` of
`ReplicatedStorage.CmdrClient` to the number of modules in its `Commands` and
`Types` folders. `ClientCmdr` requires Cmdr's client only once it has received
that many, because Cmdr's client registers only what `CmdrClient` holds when it
is required (see [Client Modules](README_CLIENT_MODULES.md)).

When the module loads, it also requires the server parts of Cmdr's `var` and
`var=` (`varServer`, `varSetServer`). Each checks Cmdr's DataStore once when
first required, and a call that arrives before that check ends waits in a
coroutine queue whose answer never reaches the `RemoteFunction`, so the client
would wait forever. Started at load, the check is over before a client that
waited for a late registration sends its first `var` (Cmdr's `init-run` line
sends one at once).

### Cmdr stat commands

`StatCommandDefinitions.Create(name, aliases, operation, statName)`
(`src/shared/modules`) builds an `Admin` command definition with `<players>`
and a non-negative whole `<amount>` (Cmdr type `nonNegativeInteger`).
`StatCommandExecutor.Execute(statKey, operation, players, amount)`
(`src/server/cmdr`) validates the amount (0 to 2^53 - 1), reports players who
left or whose profile is not loaded as failures, calls the
`secure*` profile action mapped in its `STAT_CONFIGS`, and replies with each
player's new value. The mapped stats are `money` (add and subtract) and
`rebirths` (add, set and subtract); games add their own stats to
`STAT_CONFIGS`. `AddRebirths`, `SetRebirths` and `SubtractRebirths` use it,
while the existing money commands keep their own implementation.

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
