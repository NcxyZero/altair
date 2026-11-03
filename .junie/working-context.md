# Working context

Last updated: 2026-11-03

Read this after `.junie/guidelines.md`. It is a short handoff for facts that are useful when resuming work but do not belong in stable documentation. Verify time-sensitive statements against the code, documentation, and Git status before acting on them.

## Current state

- The commit after the upstream "deboat altair" commit ports generic fixes from games built on Altair, together with the fixes from a review of that port (summarized below).
- Utility layout since the deboat merge: Altair's own utilities live in `src/util/Core`, everything else is an `altair-utils` package installed with `bash require-dependency.sh`, and `src/util/Effects` is installed and committed because `SettingsUI` requires `ClickRipple`. See [Utility Dependencies](../docs/dependencies/README.md).
- The removed `src/util/CameraNudge` FOV pulse (`PulseFov` / `ReleaseFovPulse`) is committed in the local `altair-utils` clone (`85c6f89`, `Camera/CameraNudge.luau`) but not pushed, so `bash require-dependency.sh Camera` installs it only after that push (a user action). `docs/dependencies/Camera.md` and `docs/README_CLIENT_MODULES.md` already document it and mark it pending; drop those notes after the push.
- Before testing in Studio, run `bash update.sh` (it reapplies `patches/`), then restart `bash serve.sh` and reconnect Studio, so that a fresh Rojo session also removes an old `ReplicatedStorage.client.exec` copy of the entry scripts. `wally.toml` pins `bridgenet2-fork` (`=1.1.5`) and `cmdr` (`=1.12.0`) to the versions the `patches/` files target; regenerate a patch before raising its pin.

## Recent changes

- Loading: the Initializer sets the `LocalPlayer` attribute `LoadingReleased` as the last release step on every path, right before `PlayerReady`; code that waits for the loading screen waits for it instead of looking for `LoadingUI`. See [Preload](../docs/README_PRELOAD.md).
- Security: the server's bridge remotes confirm only bridges the server itself created and never create one for a client (with request limits); Cmdr's `BeforeRun` is an allow-list, so without the role only the `Help` group runs; developer product receipts are deduplicated through `monetization.purchaseIds` and the profile MetaTag `purchaseIds`, and acknowledged only once a DataStore save holds the grant; purchase prompts have server and client cooldowns; the client-written `BreakBarrierBaseNumber` attribute is gone; redeem input and `FriendBoost` payloads are validated.
- The server bootstrap connects `PlayerAdded`/`PlayerRemoving` before `Init` and gives each controller `PlayerAdded` once per player.
- Cmdr: `ServerCmdr` registers hooks first and then sets the `CmdrClient` attribute `Registered` (its module count); `ClientCmdr` loads Cmdr's client in its own thread only once it has received that many modules. Cmdr's client registers only what `CmdrClient` holds when it is required, so a client that required it before the server's `Init` had no commands until it rejoined. `ServerCmdr` also requires Cmdr's `var`/`var=` server parts when it loads, so their DataStore check is over before a waiting client's first `var` (an earlier `var` never got an answer). Play-tested in Studio on 2026-11-03, including late registrations; the old code reproduced the bug. See [Server Modules](../docs/README_SERVER_MODULES.md) and [Client Modules](../docs/README_CLIENT_MODULES.md).
- New `GameConfig` switches, all off by default: `game.antiKick.enabled`, `game.friendBoostEnabled`, `game.vipChatTag` and `ui.windowFieldOfView` (`OpenGui` no longer touches the camera unless it is on). `core.resetButtonDisabled = true` now disables the reset button and `false` leaves it alone. `game.eventPromptId` is gone and `ui.strokeAdjuster.excludedGuiNames` is empty.
- `src/exec/Freecam.client.luau` is vendored and exempt from the style rules (see [Client Modules](../docs/README_CLIENT_MODULES.md)). `FocusController`'s HUD and camera also wait while `FreecamEnabled` is `true`.

## Games that take this version

- Set `core.resetButtonDisabled = false` in games where `true` kept the reset button, and turn on the new switches the game relies on.
- `MonetizationButton` lost the implicit `Shop` ancestor rule, the default `ONLY` price prefix and the StudPattern greying: set `KeepVisibleWhenOwned` and `PricePrefix` where needed; owned-offer buttons now hide only with `HideOnComplete` (otherwise they show the greyed `OWNED` state, as owned game-pass buttons now do too), so add `HideOnComplete` to offer buttons that should disappear once owned.
- Double `FloatSpeed` values: `FloatAnimation` no longer renders twice per frame.
- `RaycastActions` no longer listens to `LockBridge` or plays `SoundService.LocalEffects.LaserGate`; a game that fires `LockBridge` needs its own client listener.
- Create every bridge clients use on the server during startup; a client that asks for a bridge before the server created it keeps an inert bridge.
- Game client code that requires `ReplicatedStorage.CmdrClient` itself must wait for its `Registered` attribute as `ClientCmdr` does: the first require on a client fixes which commands that client gets.

## Open

- Apart from the Cmdr load wait, nothing above is play-tested in Studio yet, including the server bootstrap with several clients, the loading release, `SettingsUI` map details, the `MonetizationButton` states and the receipt save confirmation. `AntiKickController`'s VIP-server rejoin and `FriendBoostController`'s forced refresh also need a live server.
- Decisions for the user: keep `Effects` as a shipped package or move `ClickRipple` into `Core`; whether `GlobalStock.EnsureRemainingStockAmount` (still used by the rotating-stock paths) should stop caching the initial amount after a failed write.
