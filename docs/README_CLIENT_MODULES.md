# Altair - `main.client.luau` Documentation

The client entry point is `src/exec/main.client.luau`. All scripts under
`src/exec` map only to `StarterPlayer.StarterPlayerScripts`; reusable client
modules under `src/client` map to `ReplicatedStorage.client`.

This script handles the core client-side initialization for the Altair Roblox project using Luau and Rojo. It dynamically loads modules from the `modules` folder, connects tag-based behavior using `CollectionService`, and manages per-frame logic and player events.

---

## 📁 Module Folder Structure

The `modules` folder can contain the following module types, auto-detected by naming convention or the `type` field:

- `controller` – logic modules initialized on the client, supporting lifecycle callbacks.
- `module` – standard shared utility modules.
- `other` – shared singleton utilities that may opt into `PlayerRemoving`.
- `tag` – modules bound to instances tagged via `CollectionService`.
- `local_tag` – similar to `tag`, but filtered for instances relevant only to the local player.

---

## ⚙️ Initialization Flow

1. Every non-template `ModuleScript` in the `ReplicatedStorage.client` folders and
   in `ReplicatedStorage.shared.modules` is loaded. `ClientInitConfig` lists
   top-level client folders or individual module names that the initializer
   skips (`clientConfig` by default).
2. Each module is categorized by its `type` (default: `module`).
3. Controllers with a numeric `index` field are initialized first in ascending
   order (`loadFirst`, ties sorted by module name), then the others. An `Init`
   that runs longer than 2 seconds (indexed) or 5 seconds (others) logs a
   warning, and the next controller starts while it finishes. Once every
   `Init` has run and the tag modules are connected, the `Start` methods run in
   the same order; a yielding `Start` delays the controllers after it and
   `ClientBootstrapReady`.
4. Tag modules are connected to instance-added/removed signals.
5. Player and character lifecycle events are connected.
6. Runtime frame-based updates (`Heartbeat`, `Stepped`, `Render`) are routed.

The entry point sets the local player's `ClientBootstrapReady` attribute to
`false` when it starts and to `true` as its last step, after the controllers
have been initialized and started and the tag and lifecycle connections exist.
The `ReplicatedFirst` loading bootstrap waits for this attribute before it
releases the loading screen and fires `PlayerReady`; see
[Preload](README_PRELOAD.md).

---

## 🧩 Supported Lifecycle Callbacks

Controllers and tag classes may implement the following optional methods:

- `Init(self)` — Called once during initialization.
- `PlayerAdded(self, player: Player)`
- `CharacterAdded(self, character: Model)` _(for local player only)_
- `CharacterAppearanceLoaded(self, character: Model)` _(for local player only)_
- `AnyCharacterAdded(self, player: Player, character: Model)`
- `AnyCharacterAppearanceLoaded(self, player: Player, character: Model)`
- `Died(self, character: Model)` _(for local player only)_
- `AnyDied(self, player: Player, character: Model)`
- `Physics(self, deltaTime: number)` — Called every frame on `Heartbeat`.
- `Stepped(self, deltaTime: number)` — Called every frame on `PreSimulation`.
- `Render(self, deltaTime: number)` — Called every frame on `PreRender`.

---

## 🏷️ Tag Behavior

Tags are connected using `CollectionService`:

- `tag` modules respond globally.
- `local_tag` modules only react to instances belonging to the local player or their character.
- One instance may own multiple `local_tag` classes; each tag keeps an independent lifecycle.
- When an instance with the specified tag is added, the module's `new(instance)` function is called and stored.
- When removed, if the class instance has a `Destroy()` method, it is called.

---

## 🧠 GUI Behavior

All `ScreenGui` instances in `PlayerGui` have `ResetOnSpawn` set to `false` unless they have a custom attribute `SkipResetOnSpawn`.

### Cmdr access and topbar

`ClientCmdr` is initialized by the client entry point and creates a right-aligned
TopbarPlus icon for authorized players. It uses the Cmdr icon image set in
`ClientCmdr` and adds a `Cmdr` label on mobile. Selecting the icon opens and
focuses the command input; deselecting closes it. Configured activation keys
(`GameConfig.cmdr.activationKeys`, F2 by default) remain active, and changes to
the command window's visibility update the icon state. The controller's Maid
releases its connections and icon.

`ClientCmdr` loads Cmdr's client in its own thread, so the client startup never
waits for it, and only after the server has registered everything: Cmdr's
client registers only the commands, types and hooks that
`ReplicatedStorage.CmdrClient` holds when it is required, so an earlier require
left the console without commands until the player rejoined. `ServerCmdr` sets
the `CmdrClient` attribute `Registered` to the number of modules in its
`Commands` and `Types` folders, and `ClientCmdr` requires Cmdr once it has
received that many. A client still waiting after 30 seconds logs one warning
and keeps waiting. Cmdr starts disabled and is enabled only for authorized
players. Other client code that requires `CmdrClient` must wait for the same
attribute.

`GameConfig.cmdr.players` contains explicit administrator user IDs and is empty
by default. Both the client and the server `BeforeRun` hook check this list
before requesting a group rank; Studio sessions always have access. Group checks
use `GroupService:GetRolesInGroupAsync(userId, groupId)` and the highest
returned role rank (`0` for non-members). The group is the `groupId` of the
`GameConfig.roles` entry named by `GameConfig.cmdr.role`, or the group that owns
the experience. The rank must reach that role's `rank` (also in a user-owned
experience with a role `groupId`), and failed group lookups deny access. The
server caches successful rank lookups for `GameConfig.cmdr.cacheRefreshTime`
seconds. Without a configured or creator group, only the experience's user
creator and explicitly listed IDs have live access.

Without this permission only the `Help` group runs (`help`, which only lists
commands on the client). Every other group needs the permission, on the client
and on the server: Altair's `Admin`, Cmdr's `DefaultAdmin`, `DefaultDebug`
(server-side `fetch`) and `DefaultUtil` (`var` and `var=` read and write Cmdr's
DataStore on the server; `alias`, `bind`, `run` and similar), user aliases, and
commands without a group. On a client without the permission, Cmdr's join-time
auto-run aliases and their `var init` DataStore read are skipped too. To open a
group to every player, add it to `PUBLIC_GROUPS` in
`src/server/cmdr/hooks/BeforeRun.luau`.

### Asset access audit

In Studio Play, open Cmdr with F2 and run `preloadAll` (alias `preloadassets`).
Keep Studio Output visible. The client preloads ReplicatedStorage, SoundService,
ReplicatedFirst, the executor's PlayerGui and Lighting, including their
descendants. It also loads references from the shared configurations,
`SFX.Sounds`, URI attributes and PBR maps. Config-only animations and audio use
typed temporary instances.

The normal Roblox errors remain visible, including native **Click to share
access** actions. The summary marks `NO ACCESS` only when a matching native
permission denial was observed; other fetch failures remain `FAILED`. A failed
fetch can also mean an invalid asset type, deletion or a network problem.
Failure lists are grouped to avoid replacing native messages with duplicate
Output rows. Repeating the command retries the scan; concurrent duplicate
scans are rejected and temporary instances/connections are cleaned up.

The command runs on the client only. It reports access problems; the authorized
asset owner grants access using Roblox's controls. No purchases or persistent
gameplay changes are performed.

---

## 🎥 Spectate and Freecam

The Admin commands `spectate <player> [keepHUD]` and `unspectate` set the
executor's `SpectateUserId` and `SpectateKeepHUD` attributes on the server (see
[Server Modules](README_SERVER_MODULES.md)). Choosing yourself restores your own
camera. `FocusController` (index 3) points the camera at the spectated player's
`Humanoid`, otherwise at the replicated `gameProfile.focus` player, otherwise at
the local character. It re-applies the subject every frame while spectating (so
it follows the spectated player's respawns), after the local player respawns,
when the focus changes and when the camera is replaced. A respawn of the
`gameProfile.focus` player is not followed: the camera stays on the old
`Humanoid` until one of those events re-applies it. Unless `keepHUD` is `true`,
every `PlayerGui` ScreenGui is disabled while spectating, including ScreenGuis
added later; the `Cmdr` ScreenGui stays enabled only while its command window is
visible. The previous `Enabled` values are restored when spectating stops.
While the free camera is enabled (`FreecamEnabled`), the spectate HUD waits as
well. Spectating that starts or stops meanwhile applies its HUD one frame after
the free camera has stopped and restored the HUD.

`src/exec/Freecam.client.luau` is a cinematic free camera that stays dormant
until the local player's `FreecamEnabled` attribute is `true`. The Admin
commands `enableFreecam`, `disableFreecam` and `toggleFreecam` take an optional
`[player]` (default: the executor) and set that attribute on the server. While
it is active, the free camera hides CoreGui and every ScreenGui except `Cmdr`,
freezes character movement, and restores everything when it stops;
`FocusController` leaves the camera alone meanwhile. It also destroys Roblox's
built-in developer `Freecam` ScreenGui (Shift+P) whenever it appears in
`PlayerGui` and keeps its own `Freecam` ScreenGui (attribute `CustomFreecam`)
instead, so the stock developer free camera is unavailable in every Altair
game. Default controls:

- WASD / left thumbstick moves; right mouse button / right thumbstick rotates; Shift slows the movement down.
- Q and E / L2 and R2 move down and up; Z and C / L1 and R1 tilt (double-tap to reset the tilt).
- The mouse wheel / X and Y zoom the field of view.
- Holding P / R3 previews a point lock, releasing locks it, and pressing again unlocks.
- R / L3 resets the pose, field of view and roll.
- Up / D-pad up shows the mode overlay and Down / D-pad down cycles its modes: Movement, Rotation, Roll, Field of View, Custom Post Processing, Player Lock, Point Lock, UI (Screen GUIs, Leaderboard and Watermark), Controls and the Reset Freecam action. Left and Right adjust the selected mode.

`src/exec/Freecam.client.luau` is vendored third-party code (FreeCameraIAS,
about 2,650 lines). It is exempt from the
[Luau style rules](GUIDELINES.md#5-luau-code-style) of the guidelines: only
replace deprecated APIs and fix real bugs; do not restyle it. Its four
luau-lsp errors (`Enum.KeyCode.MouseDelta`, `TrackpadPan`, `MouseWheel` and
`TrackpadPinch`) are gaps in the definitions, not bugs.

---

## 🧰 Bundled Client Modules

These modules ship with Altair and stay inert until a place authors the tagged
instances, ScreenGuis or templates they expect. `AntiKickController`,
`FriendBoostController` and `VIPChatTagController` do nothing unless
`GameConfig.game.antiKick.enabled`, `GameConfig.game.friendBoostEnabled` or
`GameConfig.game.vipChatTag.enabled` is `true` (all `false` by default).

Controllers:

- `AntiKickController` — when `GameConfig.game.antiKick.enabled` is `true` and `LocalPlayer.Idled` reaches `idleSeconds`, shows a notification and asks the server to rejoin the player (at most once per `retrySeconds`); reserved servers (`PrivateServerId ~= ""` and `PrivateServerOwnerId == 0`) are skipped.
- `BackgroundMusicController` — plays the Sounds in the `SoundService.BackgroundMusic` SoundGroup one after another and scales the authored volume of that SoundGroup (recorded once in its `BaseVolume` attribute) by `musicVolume` relative to the `settingsProfile` default: the default setting plays the authored volume, `0` stops the music, and the result is clamped to 0–10.
- `BillboardVisibilityController` — multiplies the `MaxDistance` of every BillboardGui in Workspace and PlayerGui by `GameConfig.ui.billboardVisibility.defaultMultiplier`, or by `tagMultipliers[tag]` for the first tagged ancestor. The authored value is cached in `VisibilityBaseMaxDistance`; `VisibilityDistanceConfigured = true` opts a billboard out.
- `FriendBoostController` (index 2) — when `GameConfig.game.friendBoostEnabled` is `true`, asks the server to recheck a friendship when Roblox reports that the local player friended or unfriended someone.
- `UIStrokeAdjuster` (index 1) — rescales every `UIStroke` in PlayerGui and Workspace from `GameConfig.ui.strokeAdjuster.referenceViewportSize`, and BillboardGui strokes also by camera distance: a BillboardGui keeps the authored width at its `Distance` attribute (default `defaultBillboardDistance` studs). The authored width is kept in `OriginalThickness`. SurfaceGui strokes are skipped, and so is a stroke when it or an ancestor is named in `excludedGuiNames` (empty by default) or has `IgnoreUIStrokeAdjuster = true`.
- `VIPChatTagController` (index 1) — when `GameConfig.game.vipChatTag.enabled` is `true`, puts `vipChatTag.prefix` before the chat messages of players whose `vipChatTag.attribute` attribute (default `IsVIP`, which `ServerMonetization` sets for owners of the `VIP` game pass) is `true`. While enabled it owns `TextChatService.OnIncomingMessage`: game code passes its callback to `VIPChatTagController:SetChainedCallback(callback)` instead of assigning the property, and the tag goes before the prefix that callback returns. A callback assigned before the controller starts is kept only if the engine lets scripts read callbacks. With the tag disabled, `SetChainedCallback` assigns the callback directly.

World tags (`tag`):

- `BillboardDistanceAnimation` — on a BillboardGui, scales its `Frame` (or first GuiObject child) down to zero over the last part of `MaxDistance`; `DistanceAnimationRange` overrides the transition length.
- `Button3DAnimation` (`src/shared/modules`) — on a BasePart, sets `CanCollide = false`; `Animate()` presses the part down by half its height while it flashes white, then springs it back to its rest pose and colour. `RaycastController` calls it when the local character steps onto a `RaycastDetect` part whose `RaycastActionAnimation` attribute is `Button3DAnimation`. The part has `RaycastIgnore = true` until the release ends, and a press that interrupts another one keeps the original rest pose. The step sound plays only when the place authors a `SoundService.LocalEffects.ButtonStep` Sound; Altair ships none, so presses are silent by default.
- `EventBoard` — on a BasePart, shows the next upcoming Roblox Experience Event: SurfaceGui `EventSurface` with `EventImage` and `Status`, and a BillboardGui with `EventTitle` and `Countdown` labels. Both GUIs are disabled while the events load, after a load error and while no event is upcoming.
- `EventPrompt` — on an Attachment or BasePart, creates a client-only `FollowEventPrompt` ProximityPrompt that opens the RSVP prompt for the next event and hides for players already going. Texts and refresh intervals come from `GameConfig.ui.eventPrompt`.
- `Float3DAnimation` — bobs a BasePart or Model with `Float3DSpeed` and `Float3DAmplitude`; `Float3DFromBottom` keeps the motion above the authored pivot and `Float3DSynchronized` aligns instances by server time.
- `Spin3DAnimation` — spins a BasePart or Model around the Y axis of its authored pivot (`Spin3DSpeed` in degrees per second, falling back to `AnimationSpeed`, and `Spin3DPhase`). It composes with `Float3DAnimation`.

UI tags (`local_tag` in `src/client/ui`):

- `ButtonAnimation` — `AnimationTarget = "Parent"` animates the parent instead of the button; the press sound comes from the optional `GameConfig.ui.buttonSounds`; `ButtonAnimation:Click()` plays the press feedback from code. Removing the tag cancels its tweens and restores the authored `UIScale` values.
- `CloseButton`, `OpenButton` and `ToggleButton` — set `Active = true` so clicks never pass through. `OpenButton` forwards its optional `OpenArg` attribute to `OpenGui:Open`. Gamepad `ButtonB` closes the current window (`OpenGui:CloseCurrent`) on every client, and is passed on to other actions when no window was open.
- `FloatActionAnimation` — on hover, tweens its targets (Back easing over `AnimationTime` seconds, 0.35 by default, also settable per target) to their `Max` UDim2 attribute and back to `Min` when the pointer leaves. A missing `Min` is 12 pixels below `Max`, a missing `Max` 12 pixels above `Min`, and without both the target rises 12 pixels from its authored position. The targets are the GuiObjects its ObjectValue children point at (only those named after the `TargetName` attribute when one matches), otherwise a child or sibling GuiObject named `TargetName` (default `Target`).
- `FloatAnimation` — bobs a GuiObject around its authored position, vertically or, with `Horizontal = true`, horizontally; optional `FloatOffsetAmplitude` (pixels), `FloatAmplitude` (scale, default `0.1`), `FloatPhase` (starting phase in radians, random by default) and `FloatSpeed` (radians per second, default `3`).
- `IconHoverAnimation` — on hover, scales its icons up by 5% and swings them around their authored `Rotation`. With `AnimationTarget = "Parent"` the icon is the parent; otherwise the icons are the GuiObject its ObjectValue child named `IconName` (default `Icon`) points at, a GuiObject child with that name, and a sibling named after the tagged object plus `IconName`. The size changes only through the icon's `UIScale` (created when missing), the same one `ButtonAnimation` scales, so both aim at the same base scale whatever order they start in, and offset sizes are kept. When the ObjectValue changes, the hover follows the new icon.
- `MagmaGradient` and `RainbowGradient` — scroll a `UIGradient`; `MagmaGradient` uses `GameConfig.ui.magmaGradient`. Both accept a `Speed` attribute in hundredths of a gradient length per second (`Speed = 35` scrolls 0.35 lengths per second, the `RainbowGradient` default), while `GameConfig.ui.magmaGradient.speed` is in whole lengths per second (its `0.3` equals `Speed = 30`).
- `NotificationUI` — a notification feed on a container Frame under PlayerGui with a `NotificationTemplate` Frame (and an optional `ErrorTemplate` Frame). It shows server `Notification` bridge payloads and `NotificationUI.Send({ text, color, seconds, kind, channel })` calls. A payload's `channel` (`"top"` or `"bottom"`, otherwise `"top"`) picks the container: the `NotificationChannel` attribute sets the channel a container shows (`top` by default; a second container with `NotificationChannel = "bottom"` receives the `bottom` channel). Timing and the sound (`soundId = 0` disables it) come from `GameConfig.ui.notifications`.
  - Give the container a vertical `UIListLayout` with `SortOrder = LayoutOrder`: the newest notification comes first in the `top` channel and last in the `bottom` channel.
  - The text (`text`, otherwise `from > to`, otherwise `title`) goes into the top-most direct `TextLabel` of the template; nested `TextLabel`s copy it, for example as shadows. Payloads without text are ignored.
  - `kind = "error"` (also `notificationType` or `template` set to `error` or `ErrorTemplate`) uses `ErrorTemplate` with its authored colors. Without an `ErrorTemplate`, errors use `NotificationTemplate` and are tinted with `color` like every other payload.
  - Each container shows at most one notification and one error: a new payload of the same kind replaces the text and restarts the lifetime instead of stacking.
  - `Send` keeps up to 20 payloads until a container for their channel exists. Server payloads for a channel without a container are dropped.
- `SettingsUI` — a settings window (a Frame tagged `SettingsUI`) with a TopbarPlus icon. Each toggle row is a Frame under its `ScrollingFrame` (`GameMusic`, `SoundEffects`, `ClickEffect`, `Shadows`, `MapDetails`, `HideOtherPlayers`) with a `Button`; the button calls the matching `settingsProfile` action, enables its optional `On` or `Off` UIGradient, and shows the state in a `StateText` label. Only authored rows are applied:
  - `Shadows` sets `Lighting.GlobalShadows` (restored when the UI is destroyed).
  - Switching `MapDetails` off hides the details in Workspace: the Decals, Textures, lights, highlights and effects (particles, beams, trails, fire, smoke, sparkles) under `Workspace.Map`, plus instances tagged `MapDetail` and their descendants (including parts). Decals, Textures and parts are hidden through `LocalTransparencyModifier` and effects through `Enabled`, including details added later. An effect that game code turns on stays off until details return. Switching it on restores and forgets them. Tagged templates outside Workspace keep their state.
  - `HideOtherPlayers` hides other characters locally (parts, decals and textures, effects, billboards and the Humanoid name and health display).
- `ShineAnimation` — removes its generated `Shine` frame on `Destroy`.
- `WandSwingAnimation` — plays periodic damped swings on a GuiObject; `WandSwingAmplitude`, `WandSwingCooldownMinimum` and `WandSwingCooldownMaximum` tune it. Only objects with the same `WandSwingGroup` string swing together, around one pivot (the member with `WandSwingGroupPivot = true`, otherwise the first one), and a hidden member holds back its whole group. An object without `WandSwingGroup` swings alone around its own anchor.

Monetization (purchase flow in [Data Handling](README_DATA_HANDLING.md),
limited stock in [Server Modules](README_SERVER_MODULES.md)):

- `MonetizationButton` (`local_tag`) — a GuiButton that asks `ServerMonetization` to prompt a purchase through the `MonetizationPrompt` bridge on `MouseButton1Down`; clicks share the 1-second `PromptPurchase` cooldown with `MonetizationPrompt` and `RaycastActions`. It follows `state.monetization` for its game pass and its offers, and an owned button ignores clicks. Limited products show `...` until their stock arrives and `SOLD OUT` when it is empty.
  - `ProductName` (or `Product`, required): a `MonetizationConfig.products` group, or a `MonetizationConfig.passes` name with `IsGamePass = true`. `ProductVariantName` picks an entry of the group's `data`.
  - `Offers` (or `OfferNames`): comma-separated offer names, merged with the offers `MonetizationConfig` grants with the product (the `ProductVariantName` entry's `offer`/`offers`, else the group's).
  - `HideOnComplete`: hides the button, or the GuiObject its `HideObjectValue` ObjectValue child points at, after a completed purchase of this product and while its pass or one of its offers is owned. `KeepVisibleWhenOwned` keeps it visible in both cases.
  - An owned button that does not hide shows a greyed `OWNED` state: the button, an `ImageButton`'s image and its `ForegroundImage` child, and descendant Frames named `Background` turn grey, UIGradients are disabled, and the `ButtonAnimation` and `ShineAnimation` tags are removed.
  - The live Robux price goes into the first descendant TextLabel named `PriceText` (otherwise `Price`). A `PricePrefix` string attribute on that label sets text before the price (none by default), and the label's `Shadow`, `PriceShadow` or `ShadowText` child and its `ForegroundText` child copy the text.
- `MonetizationPrompt` (`tag`) — on an Attachment with a `ProductName` attribute (optional `IsGamePass`, `PromptActionText`, `PromptObjectText`), creates a `PurchasePrompt` ProximityPrompt that fires the `MonetizationPrompt` bridge and fills the parent's BillboardGui `Price` label with the price, `OWNED`, or `SOLD OUT`. Its `MaxActivationDistance` is the larger of the prompt's own distance (an authored `PurchasePrompt` child's value, else the ProximityPrompt default of 10) and the parent part's or model's horizontal size (X or Z). Triggers share the 1-second `PromptPurchase` client cooldown.
- `LimitedStockText` (`tag`) — a TextLabel with a `LimitedItemKey` attribute (a `GameConfig.game.limitedItems` key, that is the product name) and an optional `LimitedStockSuffix` shows `.../amount` until the server replicates the count, then `remaining/amount` from `gameProfile.limitedItems`.
- `MoneyUI` (`local_tag`) — a TextLabel that shows the player state value named by its `Currency` attribute (`money` by default; matched as written, then in lower case, so `Money` reads `money`) with `ConvertCurrency.SuffixFormat`. `money` gets a `$` prefix and `diamonds` a `💎` prefix unless `NoPrefix` is set, and `DisableMoneyChangeIndicator` turns off the `+`/`-` change labels shown next to it. Amounts are numbers or `ConvertCurrency.NumberToString` strings: a string is decoded with `ConvertCurrency.StringToNumber` (base 94), so decimal text such as `"1500"` shows a wrong value.
- `ShopUI` (`local_tag`) — creates preview cameras for ViewportFrames with `PreviewCameraCFrame` and `PreviewCameraFieldOfView` attributes, scrolls `Container` to its `Title{openArg}` child when opened with an `OpenArg`, and sends the text of the `EnterCode` TextBox in its `Codes` descendant to `RedeemCodeController` when the `Buy` button next to it is pressed or Enter is pressed in the box.

Other modules:

- `LevelProgressAnimator` — a plain class (`path.module`) that spring-animates a fill bar toward a level and progress.
- `UpdateSchedule` (`src/shared/modules`) — loads upcoming Roblox Experience Events for `EventBoard` and `EventPrompt`.
- `OpenGui` calls the optional UI methods `BeforeOpen(openArg)` before the open animation, `OnOpen(openArg)` once it has started, and `OnClose(closeArg)` when the close animation starts; the authored size is kept in the `OgSize` attribute. `GameConfig.ui.windowFieldOfView` (default `enabled = false`, `open = 40`): when enabled, the camera field of view is saved before the first window opens, tweened to `open`, and tweened back when the last window closes. Disabled never touches the camera. The hold-and-release field-of-view pulse (`CameraNudge:PulseFov()` / `ReleaseFovPulse()`) belongs to the [Camera](dependencies/Camera.md) package (pending: not yet in the published altair-utils Camera package).
- `SFX` (`src/util/Core`) routes sound effects through the `SoundService.SoundEffectsVolume` SoundGroup, created at runtime with volume `0.5` when it is missing. `SFX.Bind(sound)` skips sounds under `SoundService.BackgroundMusic` and keeps a sound's existing `SoundGroup`; otherwise it uses the nearest ancestor SoundGroup whose `UseSFXVolume` attribute is `true`, or `SoundEffectsVolume`. `SFX.SetVolume(volume)` (clamped to 0–1) sets `SoundEffectsVolume` and every `UseSFXVolume` SoundGroup in SoundService and binds every sound there; the client applies the `0.5` default when SFX is first required, and a `SettingsUI` with a `SoundEffects` row applies the saved `sfxVolume`. `SFX.new(soundId, volume?, doNotOverlap?, randomize?, startTime?)` seeks to `startTime` once the sound has loaded and waits for the load before it returns; a sound that does not load within 10 seconds is destroyed unplayed.
- `ConvertCurrency.SuffixFormat(value, preserveSmallDecimal?)` floors values below 1000 (with `preserveSmallDecimal` it rounds them to one decimal instead, so `999.95` becomes `1K` and `-0.04` becomes `0`), shortens larger values to one rounded decimal with a suffix (`1234` → `1.2K`, `999950` → `1M`, `-5000` → `-5K`), and returns `"0"` for NaN and infinite values.

Client halves without a server module in Altair:

- `CharacterScaleController` applies the character scale the server sends through the `CharacterScale` bridge.
- `TeleportToBaseButton` and `TeleportToTagButton` (`local_tag` GuiButtons in `src/client/modules`) fire `TeleportToBase`, or `TeleportToTag` with the button's `TeleportToTagName` attribute, on `MouseButton1Down`.

`src/server/main.server.luau` creates these three bridges at startup (`CLIENT_ONLY_BRIDGE_NAMES`), so clients get them confirmed at join without a warning, but no Altair server code listens to them or fires them. A game that uses them handles them in its own server module, for example with `GetBridge("TeleportToBase"):Connect(...)` (see [Server Modules](README_SERVER_MODULES.md)).

---

## 🔄 Runtime Event Hooks

- `Players.PlayerAdded` and `CharacterAdded`
- `CharacterAppearanceLoaded`
- `Humanoid.Died`
- `RunService.Heartbeat`
- `RunService.PreSimulation`
- `RunService.PreRender`
- `PlayerGui.ChildAdded`

Client singleton utilities with `type = "other"` receive
`PlayerRemoving(self, player)` when implemented. This stays limited to player
cleanup; other lifecycle callbacks remain controller/tag contracts.

---

## 📌 Notes

- Modules containing the word `"template"` in their name are ignored.
- Errors in requiring a module are silently caught via `pcall`.
- Module references are stored in the `path` table based on type.

---
