# AGENTS.md

This repository is a Roblox game (or the template of one) built on **Altair**: two loaders (`src/exec/main.client.luau` and `src/server/main.server.luau`) that find and start the controllers, tags and modules, Reflex state that `ServerData` saves with ProfileService, bridges for client-server traffic and utility packages installed as source into `src/util/`; Rojo syncs the files into Roblox Studio. AI agents load this file automatically. Follow it from the first message. The complete rules are in [docs/GUIDELINES.md](docs/GUIDELINES.md): they take priority over assistant modes or workflows that request conflicting actions, and over this summary where the two differ. If an instruction is unclear, ask before proceeding. An agent that cannot ask (a sub-agent, CI, a non-interactive run) never guesses identifiers and makes no change it cannot undo (publishing, pushing, deleting someone's work): it does the clear part of the task and lists the open questions in its final report.

## Mandatory start

Do these steps in order before you work on the task. Only one thing comes first: when the user says that instances are selected in Roblox Studio, read the current selection at once and report their exact DataModel paths ([Roblox Studio](docs/GUIDELINES.md#roblox-studio)).

1. Run `git status --short` and keep every unrelated change. In a folder that is not a Git repository (a plain copy), do not run `git init`: change only the files your task needs and say in your report that Git was not available.
2. Read [docs/GUIDELINES.md](docs/GUIDELINES.md), then [docs/WORKING_CONTEXT.md](docs/WORKING_CONTEXT.md). Verify the time-sensitive statements of the handoff against the code and Git status before relying on them.
3. Set up the checkout when it needs it, and read everything each script prints (see [Hard rules](#hard-rules)):
   - Fresh clone, new machine or an explicitly requested workspace setup: follow [docs/AI_SETUP.md](docs/AI_SETUP.md) and keep its setup metadata truthful. `bash init.sh` installs Rokit when it is missing, runs `update.sh` and installs the Rojo plugin.
   - After a pull, after a change to `rokit.toml` or `wally.toml`, or when `Packages/` is missing: run `bash update.sh`.
4. Check whether Roblox Studio MCP is connected: if your tools include it, make one harmless read-only request; with several Studio windows open, make sure that every request reaches the intended place. Never start Studio, publish or change the DataModel for this check. Without it, do everything else and report what was not tested in Studio.
5. When the task needs a place, universe or group ID that the user did not give, ask which source to use and offer only the available ones: values the user types, the experience open in Studio (only with Studio MCP, once the user confirms that it is the target place; `game.GameId` is the universe ID, and `game.CreatorId` is the group ID only when `game.CreatorType` is `Group`), or nonzero values in `GameConfig.game.publicGame` (`0` means not configured). Never guess an ID, copy it from another game or derive one from another. If you cannot ask, fill in nothing and report the missing identity ([Project identity](docs/GUIDELINES.md#project-identity)).
6. Before writing a new utility, look in `src/util/Core` and at the `altair-utils` packages (`bash require-dependency.sh --list`), and install a package instead of rewriting it. Before writing a new system, check the bundled modules in [docs/README_SERVER_MODULES.md](docs/README_SERVER_MODULES.md) and [docs/README_CLIENT_MODULES.md](docs/README_CLIENT_MODULES.md).

## Hard rules

- Put code where the [Placement rules](docs/GUIDELINES.md#placement-rules) say. The loaders find and start every module in the scanned folders: never call `Init`, `Start` or another callback yourself, start long-running work with `task.spawn`, and never use `template` in the name of a real module (the loaders skip it).
- Never edit the Wally packages in `Packages/` or `ServerPackages/`: their fixes are git patches in `patches/`, which `update.sh` reapplies. Never edit the generated `src/shared/reflex/ProfileTypes.luau`; run `bash generate-reflex-types.sh` after adding or removing a profile.
- `src/util/Core` holds only Altair's own utilities. General-purpose utilities are `altair-utils` packages installed into `src/util/<Package>/` ([Utility packages](docs/GUIDELINES.md#utility-packages)); never add them to `Core` and never put loose modules directly in `src/util/`.
- The server is authoritative. Client-server traffic goes through `GetBridge` and `GetFunctionBridge` (`ReplicatedStorage.util.Core`); game code creates no RemoteEvents or RemoteFunctions. Only the server creates bridges, during startup (at the top of a server module, in `Init` or in `Start`): a client bridge that the server did not create sends and receives nothing, and invoking such a function bridge fails. Server handlers validate everything a client sends (types, ranges, string lengths before patterns, ownership, prices, cooldowns) and limit how often a player may call a bridge ([Networking](docs/GUIDELINES.md#networking)).
- Player data is Reflex state in the profiles of `src/shared/reflex/`, saved by `ServerData`; never write `profileStore.Data`. A client may dispatch only the actions that a profile lists in `CLIENT_ACTIONS`, each with a validator; gameplay, inventory, progression and monetization changes go through server-validated bridges. Actions that only server code dispatches are named `secure<Action>` by convention, and the prefix protects nothing ([Reflex state](docs/GUIDELINES.md#reflex-state)).
- `ServerMonetization` is the only owner of `MarketplaceService.ProcessReceipt` (it assigns it in its `Start`); never assign it anywhere else. Products are granted by the execs and offer hooks in `MonetizationExecs`: an exec that can fail fails before it grants anything, and every exec is idempotent per `PurchaseId` ([Developer products and game passes](docs/GUIDELINES.md#developer-products-and-game-passes)). For Open Cloud work, follow [docs/MONETIZATION_OPEN_CLOUD.md](docs/MONETIZATION_OPEN_CLOUD.md): never infer the target universe and never expose the `RobloxMonetization` key.
- Game tunables live in `src/shared/config/GameConfig.luau`: one section per system, declared in the exported type, in alphabetical order, every value with a comment that says what it controls and in which unit, and the switch of a new optional system off by default. Code reads them and never hardcodes them. Clients can read everything under `ReplicatedStorage`, `GameConfig` included: values clients must not read go to `src/server/serverConfig/` ([Configuration](docs/GUIDELINES.md#configuration)).
- Code, identifiers, comments (config comments included), log messages, commit messages and documentation are in English. Talk to people in their language.
- Type-check one file per luau-lsp command. Never create test or debug scripts in the repository: experiments go to a scratch folder outside it (the one your environment gives you, or one in the OS temp folder), deleted when you are done.
- Read the whole output and the exit code of every script you run (`init.sh`, `update.sh`, `serve.sh`, `require-dependency.sh`, `scaffold.sh`, `refresh-sourcemap.sh` and any other) before the next step: check what it created, changed, removed or skipped, decide whether what it left behind stays or goes (ask the user when unsure), follow its warnings, and list the results in your final report ([Script output](docs/GUIDELINES.md#script-output)).
- Preserve unrelated and user-owned changes in the working tree, also when cleaning up before a commit.
- When a change replaces a pattern, update the documentation that describes it (`docs/GUIDELINES.md`, this file, `README.md`, the matching `docs/` file) in the same change.

## Project map

| Path | What it is |
| --- | --- |
| `src/preload/` | `ReplicatedFirst`: `Initializer.client.luau`, the loading bootstrap |
| `src/exec/` | `StarterPlayer.StarterPlayerScripts`: `main.client.luau` (client loader) and the other client entry scripts |
| `src/client/` | `ReplicatedStorage.client`: `modules/` (controllers, tags, local tags, helpers), `ui/` (logic of windows and buttons), `clientConfig/` (not loaded) |
| `src/server/` | `ServerScriptService.server`: `main.server.luau` (server loader), `modules/`, `serverConfig/` (not loaded), `serverUtil/`, `cmdr/` (admin commands) |
| `src/shared/` | `ReplicatedStorage.shared`: `config/` (`GameConfig`, `MonetizationConfig`, `RedeemCodeConfig` and other settings), `model/` (templates made in Studio), `modules/`, `reflex/` (Reflex profiles), `types/` |
| `src/util/` | `ReplicatedStorage.util`: `Core/` (Altair's own utilities) and one folder per installed utility package (`Effects` ships with Altair) |
| `Packages/`, `ServerPackages/` | Wally packages: `ReplicatedStorage.package`, `ServerScriptService.server_package` (installed by `update.sh`, not committed) |
| `patches/` | git patches for Wally packages, reapplied by `update.sh` |
| `default.project.json` | Rojo mapping of the place |
| `rokit.toml`, `wally.toml`, `altair-dependencies.toml` | tool versions, Wally packages, repositories of utility packages |
| `stylua.toml`, `.styluaignore`, `selene.toml`, `.luaurc` | StyLua, selene and Luau settings (the project is type-checked in nonstrict mode) |
| `.mcp.json` | the Roblox Studio MCP server for AI agents that read this file, on Windows; macOS and the Studio switch: [Roblox Studio](docs/GUIDELINES.md#roblox-studio) |
| `sourcemap.json`, `wally.lock` | generated by the scripts, not committed |
| `docs/` | `GUIDELINES.md`, `WORKING_CONTEXT.md`, `AI_SETUP.md`, `MONETIZATION_OPEN_CLOUD.md`, the system documentation and `dependencies/` |

Windows and the HUD are GUI made in Studio under `StarterGui.MainUI`, the loading screen is the ScreenGui `ReplicatedFirst.LoadingUI`, and visual templates made in Studio go to `ReplicatedStorage.shared.model`. Rojo keeps that Studio content, but a Rojo build contains only what is on disk: save the place in Studio ([Rojo mapping](docs/GUIDELINES.md#rojo-mapping)).

## Scripts

Run them from the project root as `bash <script>.sh` (Git Bash on Windows). `[project]` is a `*.project.json` file or its name and defaults to `default.project.json`. What each script prints and changes: [Script output](docs/GUIDELINES.md#script-output).

| When | Command |
| --- | --- |
| Fresh clone, new machine or requested workspace setup | `bash init.sh` (Rokit when missing, `update.sh`, the Rojo plugin) |
| After every pull, after changing `rokit.toml` or `wally.toml`, or when `Packages/` is missing | `bash update.sh [project]` |
| A file was created, moved or deleted; red requires in the editor | `bash refresh-sourcemap.sh [project]` |
| Keep the sourcemap fresh while you work (Windows and macOS; runs until it is stopped) | `bash watch-sourcemap.sh [project]` |
| Sync the code into Studio (runs until it is stopped; connect with the Rojo plugin) | `bash serve.sh [project]` |
| Create a module from its template | `bash scaffold.sh <target> <Name>`, targets `server-controller` (`sc`), `server-tag` (`st`), `client-controller` (`cc`), `client-tag` (`ct`), `client-local-tag` (`clt`), `client-ui` (`ui`) |
| Look for a utility package before writing a utility | `bash require-dependency.sh --list` |
| Install utility packages and the packages they depend on | `bash require-dependency.sh <Package>...` (PowerShell: `.\require-dependency.ps1 <Package>...`) |
| A Reflex profile was added, removed or renamed | `bash generate-reflex-types.sh` |
| Pull or merge, only when the user asks | `bash pull.sh`, `bash merge.sh <branch>` |

- Always pass `scaffold.sh` its target and name: without them it prompts, and an agent cannot answer.
- `require-dependency.sh` asks before it replaces an installed package and when a package is in several repositories; without an answer it skips the reinstall or uses the first repository once its input ends (`</dev/null`), and while its input stays open it waits. `--force` replaces the package folder, local edits included: pass it only when that is intended.
- When several `*.project.json` files exist, pass the same project to `serve.sh`, `update.sh`, `refresh-sourcemap.sh` and `watch-sourcemap.sh`. `init.sh` always updates `default.project.json`, and `scaffold.sh` and `require-dependency.sh` refresh its sourcemap, so run `bash refresh-sourcemap.sh <project>` after them when you work on another project.
- `update.sh` deletes `wally.lock` before `wally install`, so every update resolves the newest versions that `wally.toml` allows, and a patch that no longer matches stops it ([Wally packages](docs/GUIDELINES.md#wally-packages)).

## Testing in Studio

- Studio MCP tools act on the Studio window you pass: with several windows open, take the `studio_id` from `list_roblox_studios` on every call, and test only in a place the user named.
- While the place allows Studio access to API services, Play Solo uses the tester's real profile (the output prints `[ProfileService]: Roblox API services available - data will be saved`), and `GlobalStock` reads and writes the real stock stores that every server shares. Never reset your own data, and do not buy limited stock in a test unless the user agrees.
- Several players: run `task.spawn(function() print(game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2, {})) end)` through `execute_luau` in the Edit DataModel (the call yields until the test ends). `list_roblox_studios` then lists one window for the server, one per player (`Player1`, `Player2`, ... with the user IDs -1, -2, ..., so their profiles have their own keys) and one without an open place. Use `execute_luau` with `datamodel_type = "Server"` on the server window and `"Client"` on a player window, and `user_keyboard_input` or `user_mouse_input` on a player window (for example to type into the Cmdr console after F2). `StudioTestService:AddPlayers(n)` adds players during the test; `StudioTestService:EndTest(value)`, run in the server window, closes the test and returns `value` to the Edit call.
- Never use Team Test for tests: it runs on Roblox's servers, where `IsStudio()` is false, so game code that checks it behaves as in a live server.
- Code run through `execute_luau` has its own module cache: requiring a game module there runs a second copy with its own state (a second `ClientData` or `ServerData` would load data again). Read the game's state through instances and attributes, and change it through the game's own channels (Cmdr commands, the remotes the game listens to).
- A game command that publishes through MessagingService reaches every server of the experience, live ones included, also from Studio while it has API access: do not run such a command in a test unless it has a Studio-only branch.

## Validation before you finish

1. `stylua <changed files>` (or `stylua .`; `.styluaignore` makes it skip the vendored Freecam and the Wally packages).
2. `selene path/to/file.luau` for each changed `.luau` file (never `selene .`: it lints the Wally packages).
3. `bash refresh-sourcemap.sh [project]` when files were created, moved or deleted.
4. For each changed `.luau` file, one command per file (never a folder, several paths or a loop): `luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions="$HOME/.luau-lsp/globalTypes-1.70.1.d.luau" --ignore="Packages/**" <file>`. Download the 1.70.1 definitions once as [Running luau-lsp](docs/GUIDELINES.md#running-luau-lsp) shows. A clean file prints only `[INFO]` lines and `[WARN] client does not allow didChangeWatchedFiles registration`, and exits with 0; fix every other diagnostic.
5. `rojo build default.project.json --output build.rbxlx` succeeds (place files in the project root are gitignored; delete it afterwards).
6. `git status --short` shows only your changes and the ones that were there at the start.
7. Say what was not tested in Roblox Studio, what the scripts you ran created, changed, removed or skipped, and what is still open (for example a missing project identity).
8. Update `docs/WORKING_CONTEXT.md` after a substantial change, decision or newly found constraint.

## Documentation

- [docs/GUIDELINES.md](docs/GUIDELINES.md): canonical rules (working rules, setup and structure, placement, networking and data, style, typing, validation, Markdown, dependencies, troubleshooting)
- [docs/WORKING_CONTEXT.md](docs/WORKING_CONTEXT.md): current handoff; read it at the start, update it after substantial work
- [docs/AI_SETUP.md](docs/AI_SETUP.md): checklist and setup metadata of a workspace setup
- [docs/MONETIZATION_OPEN_CLOUD.md](docs/MONETIZATION_OPEN_CLOUD.md): developer products and game passes through Open Cloud
- [docs/README_SERVER_MODULES.md](docs/README_SERVER_MODULES.md) and [docs/README_CLIENT_MODULES.md](docs/README_CLIENT_MODULES.md): the loaders and the bundled server and client modules
- [docs/README_DATA_HANDLING.md](docs/README_DATA_HANDLING.md), [docs/README_REFLEX_PRODUCERS.md](docs/README_REFLEX_PRODUCERS.md) and [docs/REFLEX_LOGGER_GUIDE.md](docs/REFLEX_LOGGER_GUIDE.md): player and game data, Reflex producers and the Reflex logger
- [docs/README_PRELOAD.md](docs/README_PRELOAD.md) and [docs/README_LOGGER.md](docs/README_LOGGER.md): the loading screen and `Logger`
- [docs/dependencies/README.md](docs/dependencies/README.md): utility packages, one file per package, and [docs/dependencies/CREATING_DEPENDENCIES.md](docs/dependencies/CREATING_DEPENDENCIES.md) for creating them
- [docs/README_SIGNALS_AND_BRIDGES.md](docs/README_SIGNALS_AND_BRIDGES.md) is outdated: follow [Networking](docs/GUIDELINES.md#networking)
- [README.md](README.md): project overview and quick start
