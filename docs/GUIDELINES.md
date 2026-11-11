# Altair development guidelines

This document is the canonical source of the development, style and tooling rules of an Altair project: setup and structure, where code goes, networking and data, Luau style, typing, validation, Markdown, dependencies and troubleshooting. It applies to people and AI agents alike.

Project guidelines take priority over any assistant modes or operational workflows that might otherwise request conflicting actions. If an instruction is unclear, ask for clarification before proceeding. An agent that cannot ask (a sub-agent, CI, a non-interactive run) never guesses identifiers and makes no change it cannot undo (publishing, pushing, deleting someone's work); it does the clear part of the task and lists the open questions in its final report.

Where the rest of the documentation lives:

- `AGENTS.md` is the entry point that AI agents load automatically: the start steps, the hard rules, a project map, the scripts and the checks before finishing. It points here.
- `docs/WORKING_CONTEXT.md` is the short handoff of current work. Read it right after this file.
- `README.md` is the project overview and quick start.
- `docs/AI_SETUP.md` is the checklist for a workspace setup by an AI agent.
- `docs/MONETIZATION_OPEN_CLOUD.md` is the workflow for developer products and game passes through Open Cloud.
- `docs/README_SERVER_MODULES.md`, `docs/README_CLIENT_MODULES.md`, `docs/README_DATA_HANDLING.md`, `docs/README_PRELOAD.md`, `docs/README_LOGGER.md`, `docs/README_REFLEX_PRODUCERS.md` and `docs/REFLEX_LOGGER_GUIDE.md` describe the loaders, the bundled modules, data handling, the loading screen, logging and Reflex in detail.
- `docs/README_SIGNALS_AND_BRIDGES.md` shows `GetSignal` and `GetBridge`, but it is outdated: bridges have `Connect`, not `OnClientEvent` or `OnServerEvent`, and its advice to use Roblox remote functions predates `GetFunctionBridge`. Follow [Networking](#networking).
- `docs/dependencies/README.md` describes the utility packages, `docs/dependencies/CREATING_DEPENDENCIES.md` how to create them, and the other files in `docs/dependencies/` one package each.
- `docs/references/` holds copies of Roblox API reference pages (`UIDragDetector.md`).
- Altair no longer has a `.junie/` folder or a `.cursorrules` file: this file replaces `.junie/guidelines.md`, `docs/WORKING_CONTEXT.md` replaces `.junie/working-context.md`, and `AGENTS.md` replaces `.cursorrules`.

## Contents

1. [Working rules](#1-working-rules)
2. [Setup and project structure](#2-setup-and-project-structure)
3. [Architecture: where code goes](#3-architecture-where-code-goes)
4. [Networking, data and state](#4-networking-data-and-state)
5. [Luau code style](#5-luau-code-style)
6. [Typing](#6-typing)
7. [Testing and validation](#7-testing-and-validation)
8. [Markdown](#8-markdown)
9. [Dependencies](#9-dependencies)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Working rules

### Working context

- After reading this file, always read `docs/WORKING_CONTEXT.md` before inspecting or changing the project.
- Treat `docs/WORKING_CONTEXT.md` as a concise handoff of current work, decisions, constraints, and known temporary state. Verify time-sensitive statements against the code, the documentation, and Git status before relying on them.
- Update `docs/WORKING_CONTEXT.md` after a substantial feature, architectural decision, change of direction, newly discovered constraint, or material change to the current dirty-worktree handoff.
- Do not update it for trivial edits. Keep it short and remove or rewrite stale entries instead of appending an activity log.
- Put stable system contracts and setup instructions in the appropriate `docs/` file. The working context should link to that documentation rather than duplicate it.
- Never place secrets, credentials, personal data, raw logs, commit-by-commit history, or exhaustive file diffs in the working context.

### Language

- Code, identifiers, comments (including the comments in `GameConfig` and the other config modules), log messages, commit messages and documentation are in English.
- Talk to people in the language they use.

### Changes

- Inspect `git status --short` before changing anything. Preserve all unrelated and user-owned changes, and do not remove unrelated changes when cleaning up before a commit.
- When the project folder is not a Git repository (`git status` fails with "not a git repository", for example in a plain copy), do not run `git init` unless the user asks. Change only the files your task needs, do not reformat or delete files you did not change, and say in your report that the changes could not be checked against Git.
- When a change replaces a pattern, update the documentation that describes it (this file, `AGENTS.md`, `README.md`, the matching `docs/` file) in the same change.

### Workspace setup

- For a fresh or explicitly requested workspace setup, follow `docs/AI_SETUP.md` and keep its setup metadata truthful. Do not mark skipped commands or unavailable integrations as completed.
- Check whether Roblox Studio MCP is connected with a harmless read-only request. When several Studio windows are open, make sure that every request reaches the intended place. Do not start Studio, publish, or mutate the DataModel merely to make this check pass. If Studio MCP is unavailable, finish every step that does not require it and report the missing connection.

### Project identity

- The identity of the game is `GameConfig.game.publicGame` (`placeId`, `universeId`, `groupId`) in `src/shared/config/GameConfig.luau`. A value of `0` means "not configured" and is never a valid Roblox identifier.
- Never guess identifiers. Do not copy them from another game, an adjacent repository or an old response, and do not derive one from another: the place, universe, creator and group IDs are different things.
- When an identifier is needed and the user did not provide it, tell them which sources are actually available and ask which one to use: values the user types, the experience open in Studio (only when Studio MCP is connected), or nonzero values already in `GameConfig.game.publicGame`. Do not choose a source silently, and do not offer a source that is unavailable.
- If Studio is selected, ask whether the experience open in Studio is the intended target place. With permission, read `game.GameId` (the universe ID), `game.PlaceId`, `game.CreatorType` and `game.CreatorId`. When `game.CreatorType` is `Group`, `game.CreatorId` is the group ID; it is ownership metadata, not a universe ID.
- An agent that cannot ask the user never fills in identifiers. It continues with the work that does not need them and reports the missing identity at the end.
- When the connected place belongs to a new game, ask whether it is the eventual public (release) place or only a development copy (see "Place lifecycle question" in `docs/AI_SETUP.md`).

### Roblox Studio

- Roblox Studio MCP: `.mcp.json` gives AI agents that read it (such as Claude Code) Studio's built-in MCP server on Windows: `%LOCALAPPDATA%\Roblox\mcp.bat`, which runs Studio's `StudioMCP.exe`. Turn the server on once in Studio (Assistant, Manage MCP Servers, Enable Studio as MCP server) and approve it when the agent asks about `.mcp.json`. On macOS `.mcp.json` cannot start it: add it for this project in your local scope, which wins over `.mcp.json`, with `claude mcp add --scope local Roblox_Studio -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`. Other MCP clients take the same command in their own configuration.
- When the user says that instances are selected in Roblox Studio, immediately read the current Studio selection before other inspection or changes and report the exact DataModel paths so the user can safely deselect them. If names are duplicated, also record a stable distinguishing detail such as a child name or relevant attribute; do not assume the selection will remain available later in the task.
- Treat selected or Workspace-only Roblox assets as authoring sources, not runtime dependencies. When gameplay code needs a reusable visual template, place the source asset under `ReplicatedStorage.shared.model` (a Studio-owned folder that Rojo keeps) and clone or reference it there; do not make runtime behavior depend on an object remaining in `Workspace`.

### Monetization (Open Cloud)

- For Roblox developer products, game passes, or other monetization Open Cloud work, follow `docs/MONETIZATION_OPEN_CLOUD.md`. Never infer the target universe and never expose the `RobloxMonetization` key.
- Game code grants developer products only through `ServerMonetization` (see [Developer products and game passes](#developer-products-and-game-passes)).

---

## 2. Setup and project structure

### Prerequisites

- **[Roblox Studio](https://www.roblox.com/create)** installed. `init.sh` installs the Rojo plugin.
- **Git** installed. The scripts use it to apply `patches/` and to download utility packages.
- **Bash** for the repository scripts (Git Bash on Windows). Run them as `bash script.sh`.

Rokit installs the other tools, pinned in `rokit.toml`:

| Tool | Version | Used for |
| --- | --- | --- |
| `rojo` | 7.7.1 | syncs files into Studio, builds places, writes `sourcemap.json` |
| `wally` | 0.3.2 | installs Wally packages |
| `wally-package-types` | 1.7.0 | re-exports Wally package types for luau-lsp |
| `selene` | 0.32.0 | linting |
| `stylua` | 2.6.0 | formatting |
| `luau-lsp` | 1.70.1 | type checking (see [Running luau-lsp](#running-luau-lsp)) |

### Initial setup

1. Clone the repository:

   ```bash
   git clone <repository-url>
   cd <ProjectName>
   ```

2. Run the initialization script:

   ```bash
   bash init.sh
   ```

The script will:

- Install Rokit when it is missing: it downloads the latest release from GitHub (with `curl` and `unzip`), runs `rokit self-install` and adds `~/.rokit/bin` to PATH in `~/.zshrc` and `~/.zprofile` (macOS, or when your shell is zsh) or in `~/.bashrc` (other shells, including Git Bash)
- Run `update.sh` for `default.project.json` (see [Development workflow](#development-workflow))
- Install the Rojo Studio plugin (`rojo plugin install`)

Open a new terminal afterwards (or run `source ~/.zshrc` on macOS) if `rokit` is not found.

### Rojo mapping

`default.project.json` maps the files into the DataModel:

| On disk | In the DataModel |
| --- | --- |
| `src/preload` | `ReplicatedFirst` itself (it keeps instances made in Studio, such as `LoadingUI`) |
| `src/shared` | `ReplicatedStorage.shared` |
| `src/client` | `ReplicatedStorage.client` |
| `src/util` | `ReplicatedStorage.util` |
| `Packages` | `ReplicatedStorage.package` (Wally packages) |
| `src/server` | `ServerScriptService.server` (never replicated to clients) |
| `ServerPackages` | `ServerScriptService.server_package` (Wally server packages) |
| `src/exec` | `StarterPlayer.StarterPlayerScripts` (client entry scripts) |
| defined in the project file only | `StarterGui.MainUI` (ScreenGui, `DisplayOrder` 1, `ResetOnSpawn` false), `SoundService.SFX` (Folder with the Sound `SoundToClone`) and `SoundService.BackgroundMusic` (SoundGroup); the properties `StarterGui.ScreenOrientation` (`LandscapeSensor`) and `TestService.ExecuteWithStudioRun` (true) |

Require paths follow the DataModel and are absolute:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local GetBridge = require(ReplicatedStorage.util.Core.GetBridge)
local Maid = require(ReplicatedStorage.package.Maid)
local ServerData = require(ServerScriptService.server.modules.ServerData)
```

Everything under `ReplicatedStorage` (`shared`, `client`, `util`, `package`) can be read by clients, `GameConfig` included. Server-only logic, server settings and secrets belong under `ServerScriptService` (`src/server`).

Rojo removes the instances it does not know from the folders it maps from disk: `ReplicatedStorage.client`, `shared`, `util` and `package`, `ServerScriptService.server` and `server_package`, and `StarterPlayerScripts`. It keeps Studio content in `ReplicatedFirst`, in `ReplicatedStorage.shared.model` (its `init.meta.json` sets `ignoreUnknownInstances`), at the root of `ReplicatedStorage`, in `StarterGui` and `MainUI`, in `SoundService` and in services the project file does not map, such as `Workspace` and `Lighting`. Save the place in Studio: a Rojo build contains only what is on disk.

### Actual project structure

```text
AGENTS.md                    entry point for AI agents; points to docs/GUIDELINES.md
README.md                    project overview
docs/                        GUIDELINES.md (this file), WORKING_CONTEXT.md (current handoff),
                             system documentation, docs/dependencies/ for utility packages,
                             docs/references/ for Roblox API reference pages
default.project.json         Rojo mapping
rokit.toml                   tool versions
wally.toml                   Wally packages
altair-dependencies.toml     repositories of utility packages
selene.toml, stylua.toml     linter and formatter settings
.styluaignore                what `stylua .` skips: the vendored Freecam and the Wally packages
.luaurc                      Luau settings: nonstrict type checking
.editorconfig                tabs for code, two spaces for Markdown and YAML
.gitattributes               LF line endings in every checkout
*.sh, *.ps1                  setup and helper scripts (see Scripts)
scripts/                     apply-package-patches.sh, lib/platform.sh
patches/                     git patches for installed Wally packages
src/
  preload/                   ReplicatedFirst: Initializer.client.luau, the loading bootstrap
  exec/                      StarterPlayerScripts: main.client.luau (client loader),
                             Freecam.client.luau (vendored), extpackageloader.client.luau
  client/
    clientConfig/            ClientInitConfig, PromptActions, RaycastActions (not loaded)
    modules/                 client controllers, tags, local tags and helpers
    ui/                      UI modules, mostly local tags bound to GUI made in Studio
  server/
    main.server.luau         server loader
    modules/                 server controllers, tags and helpers, class/GlobalStock
    serverConfig/            ServerInitConfig, MonetizationExecs, GlobalStockConfig (not loaded)
    serverUtil/              server-only helpers
    cmdr/                    Cmdr commands/, hooks/ and types/, StatCommandExecutor, an unused store/
  shared/
    config/                  GameConfig, MonetizationConfig, RedeemCodeConfig and other settings
    model/                   Studio-owned visual templates (init.meta.json keeps them)
    modules/                 shared modules, loaded by both loaders
    reflex/                  Reflex profiles, ClientActionRegistry, ProfileTypes (generated)
    types/                   shared types: InitializerTypes, APIDictionaries, CharacterType
  util/
    Core/                    Altair's core utilities
    Effects/                 utility package shipped with Altair (SettingsUI needs ClickRipple)
    <Package>/               other installed utility packages
Packages/, ServerPackages/   Wally packages, not committed
wally.lock                   regenerated by update.sh, not committed
sourcemap.json               generated for luau-lsp, not committed
```

### Development workflow

1. **Update after pulling:** run `bash update.sh`. It runs `rokit install` (a failure there does not stop it), deletes `wally.lock` and runs `wally install`, reapplies `patches/` (`scripts/apply-package-patches.sh`), refreshes `sourcemap.json`, generates the Wally package types (`wally-package-types`) and regenerates `src/shared/reflex/ProfileTypes.luau` (`generate-reflex-types.sh`).
2. **Serve the project:** run `bash serve.sh`. It refreshes `sourcemap.json` and starts `rojo serve`. Without an argument it serves `default.project.json`, or the only `*.project.json` when there is no `default.project.json`; `bash serve.sh <project>` serves `<project>.project.json`. It runs until you stop it with Ctrl+C.
3. **Open in Roblox Studio:** with the Rojo server running, connect to it from Studio using the Rojo plugin.

When several `*.project.json` files exist (for example several places of one game), pass the same project to `serve.sh`, `update.sh`, `refresh-sourcemap.sh` and `watch-sourcemap.sh`; each defaults to `default.project.json`, and `init.sh` always updates `default.project.json`. `scaffold.sh` and `require-dependency.sh` refresh the sourcemap of `default.project.json`, so run `bash refresh-sourcemap.sh <project>` after them when you work on another project. Stop the old Rojo session before changing projects, reconnect Studio, and start a fresh Play session. Keep Studio-owned map, UI and model assets in the place; project files only map the agreed ScreenGui properties (`MainUI`: `DisplayOrder`, `ResetOnSpawn`).

### Scripts

| Command | What it does |
| --- | --- |
| `bash init.sh` | first setup: Rokit, `update.sh`, the Rojo plugin |
| `bash update.sh [project]` | tools, Wally packages, patches, sourcemap and generated types |
| `bash serve.sh [project]` | refreshes the sourcemap and runs `rojo serve` |
| `bash refresh-sourcemap.sh [project]` | writes `sourcemap.json` (`rojo sourcemap`) |
| `bash watch-sourcemap.sh [project]` | refreshes `sourcemap.json` when files under `src/` are added, removed or renamed and when a `*.project.json` changes (Windows through `watch-sourcemap.ps1`, macOS with `fswatch`, which also reacts to edits; Linux is not supported) |
| `bash scaffold.sh <target> <Name>` | creates a module from a template (see [Placement rules](#placement-rules)) |
| `bash require-dependency.sh <Package>...` | installs utility packages into `src/util` (PowerShell: `.\require-dependency.ps1`; see [Utility packages](#utility-packages)) |
| `bash generate-reflex-types.sh` | regenerates `src/shared/reflex/ProfileTypes.luau`; run it from the project root (it uses paths relative to the current folder) |
| `bash pull.sh`, `bash merge.sh <branch>` | Git helpers (`git pull --rebase --autostash`, `git merge <branch> --no-ff --no-edit`); run them only when the user asks |

- Always pass `scaffold.sh` its target and name; without arguments it prompts for them. Its targets are `server-controller` (`sc`), `server-tag` (`st`), `client-controller` (`cc`), `client-tag` (`ct`), `client-local-tag` (`clt`) and `client-ui` (`ui`).
- `require-dependency.sh` asks before it replaces an installed package (`--force` skips the question) and when a package exists in several repositories.

### Script output

Read the whole output and the exit code of every script you run (`init.sh`, `update.sh`, `serve.sh`, `refresh-sourcemap.sh`, `watch-sourcemap.sh`, `scaffold.sh`, `require-dependency.sh`, `generate-reflex-types.sh` and any other) before the next step. An exit code of 0 does not mean that every step worked: several scripts go on after a failed step and only print its error or a warning, and a script that stops can leave files behind.

- Check what the script created, changed, removed or skipped: its output (described below), `git status --short` compared with the state before you ran it, and the ignored files and folders it writes (`Packages/`, `ServerPackages/`, `wally.lock`, `sourcemap.json`).
- Decide for each result whether your task expected it, and whether what the script left behind should stay or be removed. Remove only what your own run created and nobody needs (for example a module that `scaffold.sh` created with a wrong name), never what was there before the run, and ask the user when you are not sure.
- Follow the warnings and errors: do what they say, or report why you did not. A step that failed or was skipped is not done.
- In your final report, list for each script you ran what it created, changed, removed or skipped, the warnings it printed and what you did about them, including changes outside the repository.

What the scripts print:

- `init.sh` prints `You've already installed rokit on your PC`, or `Downloading rokit from <URL>...` and `Running rokit self-install...` when it installs Rokit; it then adds `export PATH=$PATH:~/.rokit/bin` to `~/.bashrc` (or to `~/.zshrc` and `~/.zprofile`) when the line is missing. Everything `update.sh` prints follows, and `rojo plugin install` installs the Rojo plugin into Roblox Studio. It stops at the first command that fails. Rokit, the shell files and the plugin are changes outside the repository.
- `update.sh` prints `Starting update...` and then the output of `rokit install`, `wally install`, the patches (`<name>.patch applied.` or `<name>.patch is already applied.`), the sourcemap refresh (`Created sourcemap at sourcemap.json`), `wally-package-types` and `generate-reflex-types.sh`. It deletes `wally.lock`, so `wally install` may install newer versions that `wally.toml` allows, and it rewrites the tracked `src/shared/reflex/ProfileTypes.luau`. A failing `rokit install` does not stop it: its errors appear only in the output. A patch that does not match stops it with `<name>.patch does not match the installed package. Update the patch or the package version.` (exit code 1) before the sourcemap, the package types and `ProfileTypes.luau` are refreshed (see [Wally packages](#wally-packages)).
- `refresh-sourcemap.sh` prints Rojo's `Created sourcemap at sourcemap.json` when it wrote the file. `Project file not found: <file>` and `Rojo is not available on PATH. Install it with Rokit or Aftman first.` end it with exit code 1.
- `serve.sh` prints `Serving <file>.`, the sourcemap line and then Rojo's output until it is stopped with Ctrl+C; it does not end by itself. `Project file not found: <file>` (followed by `Available projects:` when there are any) or the missing Rojo ends it at once with exit code 1.
- `watch-sourcemap.sh` also runs until it is stopped. It prints `[HH:MM:SS] Regenerating sourcemap.json...` and `[HH:MM:SS] sourcemap.json updated.` for every refresh (on Windows also `Change detected: ...`). A refresh that fails while it watches prints the error and `Still watching for changes.`; a failing first refresh ends it.
- `scaffold.sh` prints `New file: <path>:1` for the module it created and then refreshes the sourcemap of `default.project.json` without output. `Warning: refresh-sourcemap.sh failed.` means that the sourcemap is stale, although the exit code is 0. An `Error:` line followed by the usage (`Destination already exists: <path>`, `A module directory already exists: <path>`, `Unknown target: <target>`) or a message about the name means that nothing was created (exit code 1). Without arguments it prompts; without a terminal to answer, it waits or repeats `Invalid target. Please choose one from the list:` until it is stopped.
- `require-dependency.sh` and `require-dependency.ps1` print `Fetching <repository> (<url>)...` for each repository in `altair-dependencies.toml`, then for each package `Installing <Package> into src/util/<Package>` and `+ <n> file(s) from <repository>`, and at the end `Installed: <packages>` or `Nothing was installed.`.
  - `<Package> is already installed, skipping.` is a dependency of another package that is already installed. `Skipped <Package>.` is a reinstall that was declined or not answered. Without a terminal the question is not shown and counts as unanswered once the input ends (`</dev/null`, or `powershell -NonInteractive`); while the input stays open, as in some agent shells, the script waits. When a package is in several repositories and nobody answers, it is installed from the first one (`No input, installing from 1) only.`).
  - `Warning:` lines report, for example, a repository that could not be fetched (its packages are not available in this run), a file skipped because another repository already installed one with that name, a Wally package missing from `wally.toml` (add it there and run `bash update.sh`) or a failed sourcemap refresh.
  - `Error: Failed: <packages>` and exit code 1 follow a package that was not found, is named `Core` or clashes with a loose module in `src/util`; the other packages of the run are still installed.
  - A reinstall (`--force`, or a confirmed question) deletes `src/util/<Package>/` first, local edits included: check `git status --short` and `git diff` for that folder afterwards.
- `generate-reflex-types.sh` prints `Formatting src/shared/reflex/ProfileTypes.luau with StyLua...` (or `StyLua not found in PATH. Skipping formatting...`) and `Generated src/shared/reflex/ProfileTypes.luau with <n> profiles`, where `<n>` counts the `*Profile.luau` files except `gameProfile`. A StyLua failure does not change the exit code. Run outside the project root, it prints `No such file or directory` errors and `with 0 profiles`, writes nothing and still exits with 0. A diff in `ProfileTypes.luau` is expected only after a profile was added, removed or renamed, or when StyLua was not found or failed (the file is then left unformatted).
- `pull.sh` and `merge.sh` print Git's output and change the current branch; run them only when the user asks.

---

## 3. Architecture: where code goes

### How the loaders load code

The client loader is `src/exec/main.client.luau` and the server loader is `src/server/main.server.luau`. Each side starts in this order:

1. The server loader creates the remotes that confirm bridges, and the bridges of the client modules that Altair ships without a server half (`CharacterScale`, `TeleportToBase`, `TeleportToTag`). The client loader sets the local player's attribute `ClientBootstrapReady` to `false`.
2. The loader requires every ModuleScript, at any depth, in the Folders directly under its side's folder (`ReplicatedStorage.client` on the client, `ServerScriptService.server` on the server; a ModuleScript directly in `src/client` or `src/server` is not loaded) and in `ReplicatedStorage.shared.modules`. It skips the top-level folders and the modules whose names are listed in `ClientInitConfig` or `ServerInitConfig` (`clientConfig` and `serverConfig` by default), and every module whose name contains `template` in any case. A module whose require fails is logged ("Failed to load module ...") and skipped.
3. The server connects `Players.PlayerAdded` and `PlayerRemoving`, then adds the players already in the game.
4. `Init(self)` runs for each controller, one after another: first the controllers with a numeric `index`, in ascending order (ties sorted by module name), then the others. When an `Init` runs longer than 2 s (indexed client controllers) or 5 s (all others), the loader logs a warning and starts the next `Init` while it finishes.
5. Tag modules (`tag`, and `local_tag` on the client) are bound to their tagged instances.
6. `Start(self)` runs for each controller in the same order, in the loader's own thread.
7. The frame callbacks are connected. The client also connects the player and character callbacks, sets `ResetOnSpawn = false` on every ScreenGui in `PlayerGui` without the attribute `SkipResetOnSpawn`, and sets `ClientBootstrapReady` to `true` as its last step.

- Every require, `Init` and `Start` runs protected (`xpcall` with a traceback). Failures are logged with `Logger.warn`, which prints only in Studio. A controller whose `Init` failed still gets its `Start` and its callbacks.
- Nothing is registered by hand: the loader finds every module in the scanned folders. To keep the loader from requiring a group of modules (for example modules that are required on demand), put them in a top-level folder of `src/client` or `src/server` and list that folder's name in `ClientInitConfig` or `ServerInitConfig`.

### Module types

The `type` field of the returned table tells the loader what a module is:

| `type` | Side | Contract |
| --- | --- | --- |
| `"controller"` | both | A singleton with lifecycle callbacks (see [Controllers](#controllers)). |
| `"tag"` | both | Has a `tag` field and a `new(instance, path)` function. The loader calls `new` for every instance with the tag and `class:Destroy(instance)` when the tag is removed. |
| `"local_tag"` | client | Like `tag`, but only for instances under the local player (for example in `PlayerGui`) or its character. The loader also connects the buttons in the class's `openButtons`, `closeButtons` and `toggleButtons` to its `Open`, `Close` and `Toggle` methods, or to `OpenGui` when the class has none. |
| `"other"` | both | A singleton utility. It receives `path` when it loads and `PlayerRemoving(self, player)`. |
| none | both | A plain module: required at startup and stored in `path.module`. |

- Controllers, tag classes and `other` modules receive `path`, the loader's registry of loaded modules (`path.controller.<Name>`, `path.module.<Name>`, `path.other.<Name>`, `path.tag[instance][tag]`, and `path.local_tag` on the client). It is typed `InitializerTypes.ClientPath` or `InitializerTypes.ServerPath` (`src/shared/types/InitializerTypes.luau`). Controllers get it before their `Init`.
- `TagManager` (`ReplicatedStorage.shared.modules.TagManager`) finds tag classes: `TagManager:GetTagClass(instance, tag)`, and on the client `TagManager:FindLocalTagClass(tag)`.
- A shared module never requires a server module: `ServerScriptService` is not replicated to clients. It reaches `ServerData` or `ClientData` through `self.path.controller`, as `Conditions` does.

### Placement rules

| What | Where |
| --- | --- |
| Client gameplay system | `src/client/modules/` (`bash scaffold.sh client-controller <Name>`) |
| Server gameplay system | `src/server/modules/` (`bash scaffold.sh server-controller <Name>`) |
| Behaviour of tagged instances | `src/client/modules/` (`client-tag`), `src/server/modules/` (`server-tag`), or `src/shared/modules/` for both sides |
| Behaviour of the local player's tagged GUI, tools or character parts | `src/client/modules/` (`client-local-tag`) |
| Logic of a UI window or button | `src/client/ui/` (`bash scaffold.sh client-ui <Name>`); the GUI itself is made in Studio under `StarterGui.MainUI` (see [UI windows](#ui-windows)) |
| Loading screen code | `src/preload/`; the `LoadingUI` ScreenGui is made in Studio in `ReplicatedFirst` |
| Bridges | the server module that handles them, created at startup (see [Networking](#networking)) |
| Player data | a Reflex profile `src/shared/reflex/<slice>Profile.luau` (see [Reflex state](#reflex-state)) |
| Game-wide data that every client reads | `src/shared/reflex/gameProfile.luau` |
| Game tunables, constants and feature switches | `src/shared/config/GameConfig.luau` (see [Configuration](#configuration)) |
| Developer products and game passes | `src/shared/config/MonetizationConfig.luau`, their grants in `src/server/serverConfig/MonetizationExecs.luau` |
| Redeem codes | `src/shared/config/RedeemCodeConfig.luau` |
| Server-only settings | `src/server/serverConfig/` |
| Client-only settings | `src/client/clientConfig/` |
| Admin (Cmdr) commands, hooks and types | `src/server/cmdr/commands/`, `hooks/` and `types/` (see [Admin commands (Cmdr)](#admin-commands-cmdr)) |
| Client-only helper | `src/client/modules/` (a plain module) |
| Server-only helper | `src/server/serverUtil/` or `src/server/modules/` |
| Helper used by both sides | `src/shared/modules/`, never duplicated client and server copies |
| Shared types | `src/shared/types/` |
| Visual templates made in Studio (models, billboards, effects) | `ReplicatedStorage.shared.model` |
| Altair's own utilities | `src/util/Core/` (never general-purpose utilities) |
| General-purpose utility for several games | a package in `altair-utils` (or another repository in `altair-dependencies.toml`), installed into `src/util/<Package>/` (see [Utility packages](#utility-packages)) |
| Fix of a Wally package | a git patch in `patches/` (see [Wally packages](#wally-packages)) |

- When adding helper logic, place it in the narrowest location that fits its responsibility.
- If you add a bridge or change a payload, update the server handler, every client sender and the shared types in the same change.
- If startup order matters, set `index` on the controllers instead of initializing anything manually.
- Never use the word `template` in the name of a real module: the loaders skip such modules.

### Controllers

| Callback | Side | When |
| --- | --- | --- |
| `index: number` | both | optional: indexed controllers initialize first, lower first, ties sorted by module name |
| `Init(self)` | both | once, one controller after another; the loader moves on after 2 s (indexed client controllers) or 5 s |
| `Start(self)` | both | once, after every `Init` and the tag binding, in the same order and in the loader's thread |
| `PlayerAdded(self, player)` | both | server: once per player, also for players who joined before its `Init`; client: players who join after startup |
| `PlayerRemoving(self, player)` | both | when a player leaves; on the server only after the controller received that player |
| `CharacterAdded`, `CharacterAppearanceLoaded`, `Died` | both | server: `(self, player, character)` for every player; client: `(self, character)` for the local player |
| `AnyCharacterAdded`, `AnyCharacterAppearanceLoaded`, `AnyDied` | client | `(self, player, character)` for the players who join after startup, never for the players already in the server (the local player included) |
| `Physics(self, deltaTime)` | both | every `RunService.Heartbeat` |
| `Stepped(self, deltaTime)` | both | every `RunService.PreSimulation` |
| `Render(self, deltaTime)` | client | every `RunService.PreRender`; the server loader connects it too, but `PreRender` is client-only, so a server `Render` never runs |

- All callbacks are optional. A controller is a ModuleScript that returns a table with `type = "controller"`. Tag classes may implement the player, character and frame callbacks too (see `docs/README_SERVER_MODULES.md` and `docs/README_CLIENT_MODULES.md`).
- `Init` may wait for data it needs (for example `ClientData:GetGameProducerAsync():expect()`), but every second it waits delays the `Init` of the controllers after it, up to the limit above. A controller that uses another controller's state in its `Init` must initialize after it: give it a higher `index`, or no `index` (controllers without one initialize after every indexed controller). `ServerData` and `ClientData` have `index` 0.
- `Start` runs in the loader's thread: a yielding `Start` delays every `Start` after it and, on the client, `ClientBootstrapReady` and the loading screen. Start loops and other long-running work with `task.spawn`.

### Runtime objects and tags

- Put temporary or debug objects created at runtime into a container folder (for example `Workspace.runtime`, created by the game) instead of cluttering the root of `Workspace`.
- Use CollectionService tags and attributes consistently for gameplay-identifiable instances. The tag of a tag module is its module name (`Module.tag = script.Name`, as in the templates).
- Apply collision groups through one config and one helper instead of hard-coding collision behaviour per descendant.
- Set `CanQuery`, `CanTouch` and `CanCollide` intentionally on temporary parts and hitboxes; do not assume the defaults are right for gameplay queries.

---

## 4. Networking, data and state

The server is authoritative. Clients send requests through bridges, the server validates them and decides, and clients observe the results through the replicated Reflex state.

### Networking

- Client-server communication goes through bridges: `GetBridge(name)` (`ReplicatedStorage.util.Core.GetBridge`) for events and `GetFunctionBridge(name)` (`ReplicatedStorage.util.Core.GetFunctionBridge`) for requests with a response. `GetBridge` returns a Bridgenet2 bridge while `AltairConfig.UseBridgenet` is `true` (the default) and a Bifrost bridge otherwise; `GetFunctionBridge` always uses Bifrost. Both return one cached bridge per name on each side.
- Game code does not create RemoteEvents or RemoteFunctions. The remotes that `ServerData` and the server loader create are part of Altair.
- Only the server creates bridges. Create every bridge that clients use on the server during startup: at the top of a server module, in `Init` or in `Start`, never later. The server confirms a client's request only for names it created; a request made while startup still runs waits for it to end (at most 30 seconds). An unconfirmed client bridge logs a warning and sends and receives nothing, and invoking an unconfirmed function bridge errors (see `docs/README_SERVER_MODULES.md`).
- On the client, the first `GetBridge` or `GetFunctionBridge` call for a name asks the server and yields until it answers.
- Bridge names are PascalCase (`MonetizationPrompt`) and at most 100 characters long; the server refuses longer names.
- For a request with a response, use a function bridge: `OnInvoke` on the server, `Invoke` (yields) or `InvokeAsync(..., callback)` on the client. Do not use Bridgenet2's `InvokeServerAsync`.
- Server handlers validate everything a client sends before they act: types, ranges and counts, ownership, prices, cooldowns and distances. Never trust client-computed results.
- Check the length of every string a client sends before running a pattern (`match`, `gsub`, `split`...) on it: some patterns are quadratic, and a long string can stall the server. `RedeemCodeController` rejects input longer than 64 characters before it trims it.
- Limit how often a player may call a bridge, for example with `CooldownManager` (`ReplicatedStorage.shared.modules.CooldownManager`), as `ServerMonetization` does for `MonetizationPrompt`.
- Events between modules of one side use `GetSignal(name)` (`ReplicatedStorage.util.Core.GetSignal`): one Signal per name on each side, never sent over the network.

A server module that handles a bridge, and a client that fires it:

```luau
-- server: src/server/modules/ShopController.luau
local BUY_COOLDOWN: number = 0.5 -- minimum seconds between two buy requests of one player
local MAX_ITEM_NAME_LENGTH: number = 40 -- longest item name a client may send

local BUY_BRIDGE: any = GetBridge("BuyItem") -- created at load, so clients get it confirmed

function ShopController:Init(): ()
  self.maid:GiveTask(BUY_BRIDGE:Connect(function(player: Player, itemName: unknown): ()
    if not CooldownManager:IsReady(player, "BuyItem") then
      return
    end

    CooldownManager:Set(player, "BuyItem", BUY_COOLDOWN)

    if type(itemName) ~= "string" or #itemName > MAX_ITEM_NAME_LENGTH then
      return
    end

    self:Buy(player, itemName) -- checks the price and the balance on the server
  end))
end

-- client
local BUY_BRIDGE: any = GetBridge("BuyItem") -- yields until the server confirms the name

BUY_BRIDGE:Fire("Sword")
```

### Player data

- `ServerData` (`ServerScriptService.server.modules.ServerData`, a controller with `index` 0) loads each player's profile with ProfileService from the DataStore named by `GameConfig.data.datastoreKey` (`"DEV"` by default), under the key `GameConfig.data.playerKeyPattern` filled with the user ID (`"%d"` by default). Changing `datastoreKey` starts every player from scratch.
- Every module in `src/shared/reflex/` whose name ends with `Profile`, except `gameProfile` and `clientProfile`, is one slice of the player's state and of the saved data. The slice is named after the file without `Profile` (`inventoryProfile.luau` is `state.inventory`), and `playerProfile` is the `player` slice.
- Reflex is the authoritative runtime state. `ServerData:SyncPlayerProfile(player)` copies the persistent slices into the ProfileService data, without the keys a profile lists in `SAVE_EXCEPTIONS` and without top-level strings that are not valid UTF-8. It runs after the profile loads, every `GameConfig.data.playerProfileSyncInterval` seconds (30 by default) and when the player leaves, before the profile is released. Never write `profileStore.Data` yourself: the next synchronization overwrites it.
- Server code reaches a player's state through the profile: `ServerData:GetPlayerProfile(player)` (nil while it loads), `ServerData:WaitForPlayerProfile(player)` and `ServerData:GetPlayerProducerAsync(player)` (both return a Promise). The player attribute `DataLoaded` is `true` once the profile is loaded.
- A new key in a profile's `DEFAULT_STATE` reaches existing saves with its default value when they load. Returning players therefore get the default, not a value that fits their progress: add a migration before gating content on a new key.
- Never add a player field named exactly `tutorial`: `ServerData` discards the loaded data when `data.player.tutorial` exists.
- Keep saved values DataStore-safe: booleans, finite numbers, valid UTF-8 strings, and tables with string keys or gapless arrays. No Instances or other Roblox types.
- `ServerData:ResetPlayerData(player)` restores every slice to a copy of its `DEFAULT_STATE` (the `Reset` admin command uses it).
- In Studio, ProfileService saves to the real DataStore when the place has Studio access to API services enabled, and to an in-memory mock store otherwise.
- `ServerData` kicks a player whose profile cannot be loaded, and a player whose profile another server loaded.
- Details: `docs/README_DATA_HANDLING.md`.

### Reflex state

- Each profile module in `src/shared/reflex/` returns `CreateProducer(initialState)`, `DEFAULT_STATE` and, when needed, `CLIENT_ACTIONS` and `SAVE_EXCEPTIONS`.
- The player producer combines the slices with `Reflex.combineProducers`, so all actions from any profile are available at the producer root level:
  - **Correct:** `producer.setHotbarItem(slot, itemId)`
  - **Incorrect:** `producer.inventory_setHotbarItem(slot, itemId)` or `producer.inventory.setHotbarItem(slot, itemId)`
  - Do not use prefixed action names like `producer.inventory_actionName`; all actions are called directly on the producer root, with a dot (`producer.secureAddMoney(100)`), never with a colon.
- Every action that server code dispatches is sent to the owning client, which applies it to its copy. Client code reads that copy through `ClientData:GetPlayerProducerAsync()` (`ReplicatedStorage.client.modules.ClientData`).
- A client may dispatch only the actions that a profile lists in `CLIENT_ACTIONS`, each with a validator from `ClientActionRegistry` (`NoArguments`, `BooleanArguments`, `NumberArguments(minimum, maximum)`). The client sends them to the server, which validates them again before it applies them; the server also requires the name to be one of the producer's actions (`getActions()`), so a client can never reach a producer method such as `resetState` or `setState`. Any other action dispatched on the client changes only the local copy and is never saved, so gameplay, inventory, progression and monetization changes go through server-validated bridges. An action name that two profiles register is rejected.
- By convention, actions that only server code dispatches are named `secure<Action>` (`secureAddMoney`). The prefix protects nothing: only `CLIENT_ACTIONS` decides what a client may dispatch.
- Game-wide state is `gameProfile`. Server code changes it through `ServerData.gameProducer`, every action is sent to every client that loaded the game data, and clients read it through `ClientData:GetGameProducerAsync()`. Nothing a client dispatches reaches the server's game state.
- `src/shared/reflex/ProfileTypes.luau` is generated by `generate-reflex-types.sh` (run by `update.sh`) from every `*Profile.luau` except `gameProfile`. Never edit it by hand; run `bash generate-reflex-types.sh` after adding or removing a profile.
- Follow the Reflex patterns for producers, actions and selectors (`docs/README_REFLEX_PRODUCERS.md`, `docs/REFLEX_LOGGER_GUIDE.md`).

### Developer products and game passes

Roblox stops delivering a receipt once `MarketplaceService.ProcessReceipt` returns `PurchaseGranted`, and `ProcessReceipt` is a single callback: assigning it again replaces the previous handler. `ServerMonetization` (`ServerScriptService.server.modules.ServerMonetization`) assigns it in its `Start`; never assign it anywhere else.

- Declare game passes in `MonetizationConfig.passes` (name and pass ID) and developer products in `MonetizationConfig.products` (`src/shared/config/MonetizationConfig.luau`): an ID, `{ id = ... }` or `{ data = { <Variant> = { id = ... } } }`, with optional `exec`/`execs` and `offer`/`offers`. An offer must be declared in `DEFAULT_STATE.offers` of `monetizationProfile` unless `GameConfig.core.monetizationOfferCreationAllowed` is `true`.
- A product's grant is an exec in `MonetizationExecs.execs` (`src/server/serverConfig/MonetizationExecs.luau`), called with `(player, data, config, receiptInfo)`, or an offer hook in `MonetizationExecs.offers`, called with `(player, offerName, receiptInfo)`; `receiptInfo` is nil when a redeem code granted the offer.
- An exec that returns `false` or errors rejects the receipt: `ProcessReceipt` answers `NotProcessedYet`, Roblox delivers the receipt again later, and the whole receipt is granted again, including the execs that ran before the failed one. An exec that can fail therefore fails before it grants anything, and every exec is idempotent per `PurchaseId`.
- `ServerMonetization` records each granted `PurchaseId` and answers `PurchaseGranted` only once a DataStore save holds it, so a receipt delivered again is not granted twice (see `docs/README_DATA_HANDLING.md`).
- Prompt purchases through `ServerMonetization`, which the `MonetizationButton` and `MonetizationPrompt` tags reach through the `MonetizationPrompt` bridge: it refuses owned passes and offers, applies the purchase cooldowns and reserves limited stock. `BuyDevProduct` prompts raw product IDs and skips these checks.
- A game pass bought in the experience is granted once `UserOwnsGamePassAsync` confirms the purchase that the prompt reported. Roblox caches `UserOwnsGamePassAsync`, so the server checks every 5 seconds for a minute and then every 30 seconds while the player stays, and the `MonetizationPrompt` bridge refuses that pass name meanwhile; a purchase it never confirms is granted on the next join. In Studio, where test purchases create no ownership, the report alone grants the pass. On join, every pass the player owns or the profile records (for example a pass a game grants as a gift) is granted. A pass named `VIP` also sets the player attribute `IsVIP`.

### Loading and readiness

- `src/preload/Initializer.client.luau` runs from `ReplicatedFirst` before the rest of the game has replicated. It has no top-level requires of `ReplicatedStorage` modules; it resolves them later with `WaitForChild` chains or after `game.Loaded`. Keep it that way.
- The loading screen is `ReplicatedFirst.LoadingUI`, a ScreenGui made in Studio. Keep it only in `ReplicatedFirst`: a copy in `StarterGui` with `ResetOnSpawn = true` comes back on every respawn.
- The bootstrap waits for `game.Loaded`, then for the player data and for the `ClientBootstrapReady` attribute (at most 25 s each). Then it releases the loading screen, sets the local player's attribute `LoadingReleased` to `true` as the last release step and fires the `PlayerReady` bridge, on every path, also after errors and timeouts.
- Code that waits for the loading screen waits for `LoadingReleased`, never for `LoadingUI` to disappear. The release restores controls, CoreGui and TopbarPlus, so a system that changes them during loading applies its change again after `LoadingReleased` or on `PlayerReady`.
- On `PlayerReady`, `ServerData` sets `state.player.ready`. Server flows that must not start before the loading screen is gone start on `PlayerReady`.
- Details: `docs/README_PRELOAD.md`.

### UI windows

- Windows and the HUD are GUI made in Studio under `StarterGui.MainUI`, whose content Rojo keeps. The logic of a window is a `local_tag` module in `src/client/ui/` (`bash scaffold.sh client-ui <Name>`), bound to the GuiObject that carries the module's name as its tag.
- `OpenGui` (`ReplicatedStorage.util.Core.OpenGui`) opens and closes windows: `OpenGui:Open(module, openArg?)`, `OpenGui:Close(module, closeArg?)`, `OpenGui:Toggle(module, openArg?)` and `OpenGui:CloseCurrent()`. A window module may define `BeforeOpen(openArg)`, `OnOpen(openArg)` and `OnClose(closeArg)`.
- Opening a normal window closes the other normal windows. A window with the attribute `AlwaysOnTop = true` opens without closing others. Normal windows blur the background and `AlwaysOnTop` windows do not, unless the attribute `EnableBlur` says otherwise. `OpenGui` keeps the authored size in the attribute `OgSize`, so code that resizes a window also updates `OgSize`.
- Buttons need no code: tag a GuiButton `OpenButton`, `CloseButton` or `ToggleButton` and set its attribute `TargetTag` (or `Target`) to the window's tag. `OpenButton` passes its optional `OpenArg` attribute to `OpenGui:Open`. Gamepad `ButtonB` closes the current window.
- `OpenGui` changes the camera field of view only when `GameConfig.ui.windowFieldOfView.enabled` is `true` (off by default).
- Details: `docs/README_CLIENT_MODULES.md`.

### Admin commands (Cmdr)

- Admin commands are Cmdr commands in `src/server/cmdr/commands/`: `<Name>.luau` returns the definition (`Name`, `Aliases`, `Description`, `Group`, `Args`, and `ClientRun` for a command that runs on the client) and `<Name>Server.luau` returns the server function. `ServerCmdr` registers `hooks/`, `types/`, Cmdr's default commands and `commands/` in its `Init`. The definitions are replicated to clients, so server logic stays in `<Name>Server.luau`.
- Give admin commands `Group = "Admin"`. The `BeforeRun` hook (`src/server/cmdr/hooks/BeforeRun.luau`) is an allow-list, checked on the client and on the server: without the Cmdr permission only the groups in `PUBLIC_GROUPS` (`Help`) run. The permission covers Studio sessions, the user IDs in `GameConfig.cmdr.players` and players with at least the rank of the `GameConfig.roles` entry that `GameConfig.cmdr.role` names, in that entry's `groupId` or else in the group that owns the experience; without either group, only the owner of a user-owned experience (see `docs/README_CLIENT_MODULES.md`).
- Commands that add, set or subtract a player stat use `StatCommandDefinitions.Create` (`src/shared/modules`) and `StatCommandExecutor` (`src/server/cmdr`); add a new stat to its `STAT_CONFIGS`. The older `AddMoney` and `SubtractMoney` commands keep their own implementation.
- Client code that requires `ReplicatedStorage.CmdrClient` waits for its attribute `Registered` first, as `ClientCmdr` does: Cmdr's client registers only the commands that exist when it is first required.

### Connection management

- Always use `Maid` (`ReplicatedStorage.package.Maid`) for GUI connections and other cleanup tasks.
- Use `self.maid:GiveTask(connection)` instead of manual connection management. Avoid storing individual connections as properties when a Maid can handle them directly.
- Bridge connections (`bridge:Connect(...)`) can be given to a Maid as well.
- A Maid also takes a thread and cancels it when it is cleaned, but the task type of `GiveTask` does not list `thread`, so cast it: `self.maid:GiveTask(task.spawn(work) :: any)`.

### Logging

- Debug output goes through `Logger` (`ReplicatedStorage.util.Core.Logger`): `Logger.print`, `Logger.warn`, `Logger.error` (reports through `TestService:Error`), `Logger.errorStack` (raises an error) and `Logger.assert`.
- `Logger` prints only in Studio, while `GameConfig.debug.loggerShowInStudio` is `true` (the default), and it prefixes every message with the calling file and line. Do not add source labels such as `"[GameController]"` to messages.
- Use plain `print` or `warn` only for output that must also appear in live servers, and never for sensitive data.
- Details: `docs/README_LOGGER.md`.

---

## 5. Luau code style

These rules apply to all code in `src/`. Vendored third-party code is exempt: in `src/exec/Freecam.client.luau` (FreeCameraIAS), only replace deprecated APIs and fix real bugs, and do not restyle it. Wally packages are never edited (see [Wally packages](#wally-packages)).

### Formatting

- The project uses StyLua 2.6.0 for formatting. `stylua.toml` spells out its settings (tabs, 120 columns, LF line endings, double quotes, parentheses on every call) and turns on sorted requires. Run it before committing changes:

  ```bash
  stylua .
  ```

  `.styluaignore` makes it skip the vendored `src/exec/Freecam.client.luau` and the Wally packages, also outside a Git repository. `stylua <paths>` is enough whenever you changed a few files.
- `.gitattributes` checks out every text file with LF line endings on every platform, whatever `core.autocrlf` says. A checkout made before that rule keeps its CRLF files until Git writes them again: `stylua --check` fails on such a file, and `stylua <path>` rewrites it with LF without changing its content in Git.
- Do not use multiple statements in one line.
- Do not use section title comments in code (e.g., "-- Constants", "-- Private functions").
- Do not describe a file in a comment at its top.
- When declaring a new variable and just after there is an `if` checking this variable, do not separate them with a blank line.

  Example:

  ```luau
  local template: Folder = workspace:FindFirstChild("Template")
  if not template then
    return
  end
  ```

- Make blank lines between code blocks and above `return`/`break`/`continue` keywords if it isn't the first line in the block; when you create a new variable and assign its properties, it should be together, when you switch to another variable, it should be separated by a blank line; separate lines where you assign values (including from calls) and not assigning call functions by blank lines. Separate calls on objects and the rest of calls. Example of all in this point:

  ```luau
  local new: Part = Instance.new("Part") :: any
  new.Name = "NewPart"
  new.Anchored = true
  new.CanCollide = false
  new.Parent = workspace

  local folder: Folder = workspace:WaitForChild("Template")
  folder.Name = "New"
  folder.Parent = new

  local set: { string } = {}

  local function newFunction(): true
    return true
  end

  local function nextFunction(): boolean
    if newFunction() then
      print("Success!")

      return true
    end

    return false
  end

  part.CanQuery = false
  part.CanTouch = false
  part.Massless = newFunction()

  part:SetAttribute("Ready", nextFunction())
  part:SetAttribute("Ready", nextFunction())

  table.insert(set, "1")
  table.remove(set)
  ```

Code in `.luau` files is indented with tabs (StyLua); examples in Markdown use two spaces.

### Naming

- Do not use abbreviations in variable names; use full, descriptive names for readability (e.g., use `player` instead of `plr`, `callback` instead of `cb`, `connection` instead of `conn`).
- Use "controller" terminology instead of "service" for game system modules.
- Constants are `UPPER_SNAKE_CASE` and other locals are `camelCase`. The main table of a module and its type are `PascalCase` and named after the module (`local FocusController: FocusController`).
- Bridge names are PascalCase (see [Networking](#networking)). Reflex profile files are `<slice>Profile.luau` with a camelCase slice name, and server-only actions are `secure<Action>` (see [Reflex state](#reflex-state)).
- Utility package folders are PascalCase (`Math`, `Camera`), and every module file is named after what it returns. `Core` is reserved for Altair's core utilities.

### Control flow

- Avoid unnecessary nesting. Prefer guard clauses, early returns, and `continue` so the main execution path stays flat and readable.
- Use bare `return` instead of `return nil`; only use `return nil` when returning additional values after `nil` (for example, `return nil, false`).
- Prefer using `and`/`or` logical operators instead of `if-else` statements when appropriate for cleaner, more readable code. Use `a and b or c` only when `b` can never be `false` or `nil`; otherwise use an `if` expression (`if a then b else c`).

  Example of preferred logical operators:

  ```luau
  -- Preferred: using 'and' for conditional execution
  local success: boolean = validate() and process() and save()

  -- Preferred: using 'or' for default values
  local playerName: string = player.Name or "Unknown"

  -- Preferred: using 'and' for conditional assignment
  local result: string? = isValid and computeResult() or nil

  -- Instead of verbose if-else statements, use logical operators when appropriate
  ```

- Do not declare `local function` inside other functions; define methods on `self` instead to keep behavior organized and consistent.

### Module structure

Follow the code organization pattern:

1. Service imports at the top
2. Module imports after services (StyLua sorts consecutive `require` lines)
3. Instances (use `:WaitForChild()`) if present
4. Type definitions, including the type for the main table to return with the same name, including everything it does/can contain. The main table type needs to be always exported, the rest when necessary. Main table type keys order (without empty lines, follow alphabetical order for every category):
   1. Functions (remember to include `self: TypeName` as a first argument if the function contains `self`)
   2. Tables (specify key type number if the table isn't an array, for example, there is `table[0] = true`)
   3. Primitive values
   4. Objects (specify descendants used in code if not necessary to add as a new main table entry)
   5. `Maid`s, `Signal`s, etc.
5. Main table to return, example: `local Module: Module = {} :: any`
6. Local variables and constants. In this order:
   1. Constants with comments, example: `local DROP_TIME: number = 5 -- determines drop time`
   2. Constant tables with the comment line above
   3. Changeable variables with comments
   4. Changeable tables with comments
   5. Other variables without values set at this moment. If the given variable is never nil after setup on startup, do not add `?` to the type, otherwise you can
7. Functions with proper type annotations

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Core.Logger)
local Maid = require(ReplicatedStorage.package.Maid)
local ServerData = require(ServerScriptService.server.modules.ServerData)

export type CoinController = {
  GiveBonus: (self: CoinController, player: Player) -> (),
  Init: (self: CoinController) -> (),
  PlayerRemoving: (self: CoinController, player: Player) -> (),
  bonusCounts: { [Player]: number },
  path: InitializerTypes.ServerPath,
  type: string,
  maid: Maid.Maid,
}

local CoinController: CoinController = {
  bonusCounts = {},
  type = "controller",
  maid = Maid.new(),
} :: any

local BONUS_INTERVAL: number = GameConfig.coins.bonusInterval -- seconds between two coin bonuses

-- coins of one bonus by membership type
local BONUS_AMOUNTS: { [Enum.MembershipType]: number } = {
  [Enum.MembershipType.None] = GameConfig.coins.bonus,
  [Enum.MembershipType.Premium] = GameConfig.coins.premiumBonus,
}

local bonusesGiven: number = 0 -- bonuses given since the server started

function CoinController:GiveBonus(player: Player): ()
  local profile: ServerData.ServerPlayerProfile = ServerData:GetPlayerProfile(player) :: any
  if not profile then
    return
  end

  local amount: number = BONUS_AMOUNTS[player.MembershipType] or BONUS_AMOUNTS[Enum.MembershipType.None]

  profile.producer.secureAddMoney(amount)

  bonusesGiven += 1
  self.bonusCounts[player] = (self.bonusCounts[player] or 0) + 1
end

function CoinController:Init(): ()
  self.maid:GiveTask(task.spawn(function(): ()
    while true do
      task.wait(BONUS_INTERVAL)

      for _index: number, player: Player in Players:GetPlayers() do
        self:GiveBonus(player)
      end
    end
  end) :: any)
end

function CoinController:PlayerRemoving(player: Player): ()
  Logger.print(`{player.Name} got {self.bonusCounts[player] or 0} of {bonusesGiven} bonuses`)

  self.bonusCounts[player] = nil
end

return CoinController
```

### Controllers and lifecycle

- Controller modules are initialized only by the loaders (`src/exec/main.client.luau` and `src/server/main.server.luau`), never by other modules. Never call `Init`, `Start` or another callback yourself.
- Do not call a module's `Init()` function at the end of the module itself.
- Long-running work starts with `task.spawn`, not in a waiting `Init` or `Start` (see [Controllers](#controllers)).

### Configuration

- Store gameplay-tunable values in the appropriate existing configuration module. Use `GameConfig` (`src/shared/config/GameConfig.luau`) for game-wide values instead of hardcoding them in controllers or UI modules, `MonetizationConfig` for products and passes, `RedeemCodeConfig` for codes, and `src/server/serverConfig/` for values that clients must not read.
- Group the values of one system in one table of `GameConfig` (a section such as `ui.notifications` or `game.antiKick`, or a new top-level section such as `coins`), and declare it in the exported `GameConfig` type. Keep sections and keys in alphabetical order, and give every value a comment that says what it controls and in which unit.
- Code reads the values (`GameConfig.coins.bonusInterval`). A module may give a value a constant name (`local BONUS_INTERVAL: number = GameConfig.coins.bonusInterval`, as in the [Module structure](#module-structure) example), but it never writes the tunable value itself.
- The switch of a new optional system is off by default, as `game.antiKick.enabled`, `game.friendBoostEnabled`, `game.vipChatTag.enabled` and `ui.windowFieldOfView.enabled` are. The older `core.playerCollisionsDisabled` is `true` by default, so players do not collide unless a game turns it off.

A new section in `src/shared/config/GameConfig.luau`, in the exported type and in the table:

```luau
-- in the exported GameConfig type
coins: {
  bonus: number,
  bonusInterval: number,
  premiumBonus: number,
},

-- in the table
coins = {
  bonus = 10, -- coins of one bonus
  bonusInterval = 60, -- seconds between two coin bonuses
  premiumBonus = 20, -- coins of one bonus for Premium members
},
```

### Roblox API usage

- Do not use the `.Touched` event (`BasePart.Touched`); use spatial queries such as `workspace:GetPartsInPart()` instead.
- For `GuiButton` input, use `MouseButton1Down` instead of `Activated`, because `Activated` is unreliable on some mobile devices.
- Do not use `ValueBase` instances as gameplay state. Native Roblox `leaderstats` explicitly requested for the player list are the only exception; they must mirror authoritative server data and must never become the source of truth. Outside that exception, only use `ObjectValue` when attributes cannot represent an object, and still prefer not to use it.
- Do not use the second argument of `Instance.new()`; it is deprecated. Set the parent in a new line after assigning the other properties. The order of assigning properties is: `Name`, the rest of the properties in alphabetical order, `Parent`.
- Do not use the `.Chatted` event; it doesn't work with the new Roblox chat. Use `TextChatService` instead.
- Do not create a chat command when the command is not specified to be for chat; then assume you are asked to create a Cmdr command (see [Admin commands (Cmdr)](#admin-commands-cmdr)).
- Do not use `SetPrimaryPartCFrame()`, as it is deprecated; always use `PivotTo()`, `GetPivot()`, `ScaleTo()` and `GetScale()` instead.
- Prefer `:FindFirstChildWhichIsA()` over `:FindFirstChildOfClass()` unless necessary.

### Values, strings and time

- Use `UDim2.fromScale()` and `UDim2.fromOffset()` instead of `UDim2.new()` when you are not setting both scale and offset.
- Use `Color3.new()` instead of `Color3.fromRGB(0, 0, 0)`, as zeros are the default values.
- Use `CFrame.identity` instead of `CFrame.new(0, 0, 0)` or `CFrame.new()`, as zeros are the default values.
- Use `CFrame.fromAxisAngle()` instead of `CFrame.Angles()` when only one axis is not zero.
- Use `Vector2`'s and `Vector3`'s `.xAxis`, `.yAxis`, and `Vector3`'s `.zAxis` in `CFrame.fromAxisAngle()` and when only one axis is not zero, for example: `Vector2.yAxis * 5`.
- Use `Vector2`'s and `Vector3`'s `.zero` and `.one` instead of `.new()`, `.new(0, 0, 0)` and `.new(1, 1, 1)`.
- Use `Vector2`'s and `Vector3`'s `.one` when all axes are the same (e.g., use `Vector3.one * 5` instead of `Vector3.new(5, 5, 5)`).
- Use integer division (`//`) instead of regular division with `math.floor()` (e.g., use `value // 2` instead of `math.floor(value / 2)`).
- Always use compound assignments (for example, `+=`, `-=`, `%=`, `..=`, `//=`).
- Use direct string methods instead of string library functions (e.g., use `text:split("")` instead of `string.split(text, "")`).
- When formatting strings with backticks in Luau, use `{}` directly without `$`; `${}` would appear literally because Luau already interpolates.
- Prefer `os.clock()` and the `DateTime` library for time.
- Do not use the `pairs()` function in Luau code; iterate tables directly (`for key, value in items do`) or use other iteration methods.

### Variables and cleanup

- Do not leave unused variables; either add `_` at the beginning of the name or remove it.
- Use the `Maid` package for connection handling. Remember to use `:DoCleaning()` always when necessary to avoid memory leaks. Prefer `:DoCleaning()` over `:Destroy()`: in the Maid fork Altair uses (`ncxyzero/maid-fork`), `:Destroy()` also cleans, but it marks the maid as dead, so a later `GiveTask` and a second `:Destroy()` error.

---

## 6. Typing

- `.luaurc` sets nonstrict type checking for the whole project. Do not add `--!strict` at the top of files, but also do not remove it when already present. Keep the `--!nocheck` of the loaders and `Logger` and the `--!nonstrict` of the vendored Freecam.
- Use type annotations for function parameters and return values, for example: `local function foo(bar: string): boolean`; use `()` for functions that return nothing.
- Use `any`, `unknown`, or `never` when appropriate for types that can't be determined precisely.
- Type local variables at declaration (except for `game:GetService()` and `require()` calls).
- Export the main table type of every module (see [Module structure](#module-structure)), and use the exported types of Altair's modules and packages: `InitializerTypes.ClientPath` and `InitializerTypes.ServerPath` for `path`, `ServerData.ServerPlayerProfile`, `ProfileTypes.PlayerProducer`, `gameProfile.Producer`, `Maid.Maid`, `Signal.Signal<...>`, `Promise.TypedPromise<...>`.
- When a variable is immediately guarded with `if not variable` you should not type it as optional; `luau-lsp` will still assume `nil` inside that block. Declare it as non-optional (use a type assertion if needed) and, when creating it inside the guard, assign the new local back before reuse. Example:

  ```luau
  local grid: UIGridLayout = frame:FindFirstChildWhichIsA("UIGridLayout") :: any
  if not grid then
    local newGrid: UIGridLayout = Instance.new("UIGridLayout")
    newGrid.CellPadding = UDim2.fromOffset(8, 8)
    newGrid.CellSize = UDim2.fromOffset(140, 170)
    newGrid.Parent = frame

    grid = newGrid
  end
  ```

- If you encounter persistent type errors that you can't resolve after several attempts:
  1. Try using more flexible types like `any` or union types
  2. Use type assertions when necessary (e.g., `value :: any`)
  3. If all else fails, you may skip typing for that specific case, but document why

### Running luau-lsp

- The project uses luau-lsp for type checking. Rokit installs it on Windows, macOS and Linux (version 1.70.1, pinned in `rokit.toml`); there is no executable in the repository.
- `luau-lsp analyze` needs the Roblox definitions that match its version. Download them once to a folder outside the repository. The file name carries the version: when the version in `rokit.toml` changes, download the file of the new version.

  ```bash
  curl -fsSL --create-dirs -o "$HOME/.luau-lsp/globalTypes-1.70.1.d.luau" https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.1/scripts/globalTypes.None.d.luau
  ```

  On Windows PowerShell use `curl.exe` with the same arguments. Definitions of another luau-lsp version can fail to load (`Failed to load definitions`).
- Run it from the project root on a single file, after `bash refresh-sourcemap.sh` so that `sourcemap.json` contains every file:

  ```bash
  luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions="$HOME/.luau-lsp/globalTypes-1.70.1.d.luau" --ignore="Packages/**" src/server/modules/ServerData.luau
  ```

  The same command works in PowerShell.
- **Important:** run `luau-lsp analyze` on a single file path only. Do not pass folders (e.g. `src` or `.`), do not pass multiple file paths in one command, and do not batch it with `foreach` or other loops; run it once per file.
- `--ignore="Packages/**"` hides the diagnostics inside the Wally packages, which are noise. A clean file prints only `[INFO]` lines (the definitions and the `.luaurc` it loaded) and `[WARN] client does not allow didChangeWatchedFiles registration`, and exits with 0. Every other line is a diagnostic that names the file, line and column (`path(12,5): TypeError: ...`) and must be fixed.
- Without `--platform=roblox`, the sourcemap and the definitions, luau-lsp reports noise such as `Unknown global 'game'` and unknown Roblox types or requires. Fix the command line instead of the code, and do not spend time on editor setup during normal development tasks. Without network access to download the definitions, use luau-lsp as a best-effort checker and ignore that noise.
- Definitions older than a Roblox API make luau-lsp report that API as unknown (`Key '<name>' not found in class '<class>'`). With the 1.70.1 definitions no such gap is known in Altair's code; when you meet one, check the API in the Roblox documentation and name the gap in your report instead of changing working code.
- A scratch file outside the repository can be type-checked the same way, from the project root.

---

## 7. Testing and validation

- **Do not create test files** in the project directory. This applies even when a task mode would otherwise require writing tests or repro scripts.
- **Do not create debug scripts** in the project directory for testing or debugging purposes. Experiments go to a scratch folder outside the repository: the scratch folder your environment provides, or a folder in the OS temp folder (`$TMPDIR` or `/tmp` on macOS and Linux, `%TEMP%` on Windows). Delete it when you are done.
- Use luau-lsp for type checking and validation instead of creating separate test scripts.
- **Important:** when a file has been created, moved or deleted, `sourcemap.json` must be refreshed for correct editor IntelliSense and luau-lsp resolution.
  - Quick fix (sourcemap only): `bash refresh-sourcemap.sh`
  - Full update (tools, Wally packages, patches, sourcemap, generated types): `bash update.sh`
  - Optional (Windows and macOS): keep the sourcemap up to date automatically with `bash watch-sourcemap.sh` (macOS requires `brew install fswatch`)
- For every changed `.luau` file:
  1. Format it with StyLua (`stylua <path>` or `stylua .`).
  2. Lint it with selene, one file at a time: `selene path/to/file.luau`. **Important:** do not run `selene .`; it also lints the Wally packages in `Packages/` and reports thousands of errors there.
  3. Type-check it with luau-lsp, one file per command (see [Running luau-lsp](#running-luau-lsp)).
- For functionality verification:
  1. Use the type checking tools (luau-lsp and selene).
  2. Test functionality directly in Roblox Studio with `bash serve.sh` connected.
  3. Use the build system to verify that the place builds: `rojo build default.project.json --output build.rbxlx` (place files in the project root are gitignored; delete the file afterwards).
- Report truthfully what was not tested, for example "not play-tested in Studio".
- Report what the scripts you ran created, changed, removed or skipped, and the warnings they printed (see [Script output](#script-output)).

---

## 8. Markdown

- Blank lines should surround fenced code blocks, headings, and lists.
- No multiple spaces after list markers.
- Indent: two spaces as in `.editorconfig`.
- Always specify the fenced code language, including `text`.
- Do not specify the fenced code language as `lua`; use `luau` instead.
- Write documentation in English (see [Language](#language)), and link to the `docs/` file that describes a system instead of copying it.

---

## 9. Dependencies

### Tools

- Tools are managed by Rokit in `rokit.toml` (see [Prerequisites](#prerequisites)). After changing `rokit.toml`, run `bash update.sh`; it runs `rokit install`.
- When you change a version in `rokit.toml`, update the table in [Prerequisites](#prerequisites) in the same change; for luau-lsp, also change the definitions version in [Running luau-lsp](#running-luau-lsp), in `AGENTS.md` and in the Testing example of `README.md`.
- VS Code (`.vscode/`) and the pinned tools: the StyLua extension formats with the `stylua` that Rokit pins (`stylua.searchBinaryInPATH`) when VS Code finds it on its PATH (restart VS Code after `bash init.sh` installs Rokit; otherwise the extension falls back to its own copy). The luau-lsp extension writes `sourcemap.json` with the Rokit `rojo` but runs its own server with the newest Roblox definitions and flags, so its diagnostics can differ from the pinned luau-lsp; the checks in [Testing and validation](#7-testing-and-validation) decide. The selene extension is not recommended: it downloads its own selene, and all selene versions share one Roblox standard library cache that an older selene cannot read once a newer one wrote it (`Could not collect standard library`). To lint in the editor anyway, set `selene.selenePath` in your user settings to the absolute path of the Rokit shim (`C:/Users/<name>/.rokit/bin/selene.exe` on Windows, `/Users/<name>/.rokit/bin/selene` or `/home/<name>/.rokit/bin/selene` elsewhere).

### Wally packages

- Third-party Luau libraries are managed with Wally (`wally.toml`). Their keys are `BezierTweens`, `Bifrost`, `Bridgenet2`, `CameraShaker`, `Cmdr`, `Fastcast`, `Maid`, `ProfileService`, `Promise`, `Reflex`, `Signal`, `SimpleSpline`, `WindShake` and `topbarplus`, and `Lapis` for the server. `Bridgenet2` and `Maid` are forks (`ncxyzero/bridgenet2-fork`, `ncxyzero/maid-fork`).
- To add a new dependency:
  1. Add it to `wally.toml`: `[dependencies]` for shared and client code, `[server-dependencies]` for server-only code.
  2. Run `bash update.sh` to install it (packages, patches, sourcemap and package types).
  3. Require it as `ReplicatedStorage.package.<Name>` (or `ServerScriptService.server_package.<Name>`), where `<Name>` is its key in `wally.toml`.
- `wally.lock`, `Packages/` and `ServerPackages/` are not committed. `update.sh` deletes `wally.lock` before `wally install`, so every update resolves the newest versions that `wally.toml` allows; pin a version with `=` when a game must keep it.
- Fixes to installed Wally packages are tracked in `patches/` as git patches (paths relative to the project root) and reapplied by `update.sh` through `scripts/apply-package-patches.sh`: a patch that is already applied is skipped, and a patch that no longer matches stops the update. Do not edit files under `Packages/` directly. Pin a patched package to the exact version the patch targets (`"scope/name@=x.y.z"`), as `wally.toml` does for `bridgenet2-fork` and `cmdr`, and regenerate its patch before raising that pin.

### Utility packages

- `src/util` contains only folders. Altair's core utilities (used by Altair itself) live in `src/util/Core` and are required as `require(ReplicatedStorage.util.Core.<Module>)`.
- Do not add general-purpose utilities to `src/util/Core`, and do not put loose modules directly in `src/util`.
- Extra utilities are installed from the repositories in `altair-dependencies.toml` (default: `altair-utils`) with `bash require-dependency.sh <Package>` or `.\require-dependency.ps1 <Package>`. The packages that a package lists in its `dependencies` are installed with it.
- Installed packages are placed in `src/util/<Package>/` and required as `require(ReplicatedStorage.util.<Package>.<Module>)`. They are plain source files of the project: commit them, edit them, or delete the folder to uninstall. A reinstall replaces the folder, local edits included.
- Altair ships `src/util/Effects` because `SettingsUI` requires `ReplicatedStorage.util.Effects.ClickRipple`; keep it.
- The installer warns when a package needs a Wally package that is missing from `wally.toml`; add it there and run `bash update.sh`.
- Before writing a new utility, check whether a package already provides it (`bash require-dependency.sh --list`).
- New general-purpose utilities belong in a package in `altair-utils`, see `docs/dependencies/CREATING_DEPENDENCIES.md`.

---

## 10. Troubleshooting

### Common issues

1. **`rokit` not found:** run `bash init.sh` and make sure that `~/.rokit/bin` is in your PATH. On macOS with zsh, check `~/.zshrc` or `~/.zprofile`; open a new terminal or run `source ~/.zshrc` after `init.sh`.
2. **Wally packages not found** (red `ReplicatedStorage.package` requires): run `bash update.sh`.
3. **`Project file not found: default.project.json`:** the game has no `default.project.json`. Pass the project to the scripts, for example `bash update.sh <project>`; `init.sh` always uses `default.project.json`.
4. **`update.sh` stops with `<name>.patch does not match the installed package`:** the installed Wally package is not the version the patch targets. Pin that version in `wally.toml`, or regenerate the patch for the new version.
5. **Rojo connection issues:** make sure the Rojo server is running (`bash serve.sh`) on the port the Studio plugin uses (Rojo's default is 34872) and that the Rojo plugin is installed in Roblox Studio (`init.sh` installs it with `rojo plugin install`). Reconnect after switching project files.
6. **Red `require(...)` or unknown modules in the editor after adding files:** run `bash refresh-sourcemap.sh` (with the project name when you work on another project).
7. **luau-lsp reports `Unknown global 'game'`:** pass `--platform=roblox`, `--sourcemap=sourcemap.json` and `--definitions` (see [Running luau-lsp](#running-luau-lsp)).
8. **A controller does not start:**
   - Confirm that the module returns a table with `type = "controller"`, that it is in a scanned folder, that neither its folder nor its name is listed in `ClientInitConfig` or `ServerInitConfig`, and that its name does not contain `template`.
   - Read the Studio output for `Failed to load module ...`, `Failed to initialize controller ...` and `Failed to start controller ...`. The loaders log with `Logger.warn`, which prints only in Studio.
   - A warning that its initialization `exceeded ...s, continuing to next` means that its `Init` waits; a yielding `Start` delays every `Start` after it.
   - Set `index` if it depends on another controller's `Init`.
9. **`Bridge "<name>" was not created by the server`:** create the bridge on the server during startup, for example with `GetBridge("<name>")` at the top of a server module.
10. **The loading screen stays for 25 s and `ClientBootstrapReady was not set within 25 seconds` is printed:** a client controller yields in `Init` or `Start`.
11. **A player is kicked on join:** `Failed to load your data` means that ProfileService could not load the profile; `Your data has been loaded on another server` means that another server loaded the same profile.
12. **Player data does not save in Studio:** enable Studio access to API services in the place; without it, ProfileService uses an in-memory mock store.
13. **A window or button does nothing:** the GUI must carry its module's tag and be under the local player's `PlayerGui`, and the button's `TargetTag` (or `Target`) attribute must match the window's tag.
14. **The Cmdr console has no commands:** only players with the Cmdr permission (and every Studio session) can use Cmdr. Client code that requires `ReplicatedStorage.CmdrClient` before its attribute `Registered` is set gets no commands until the player rejoins.
15. **`Rejected client profile action for <player>: action_not_registered`:** the client dispatched an action that no profile lists in `CLIENT_ACTIONS`. Register it with a validator, or move the change to a server-validated bridge.
16. **selene stops with `Could not collect standard library` (`unknown field lua_versions`):** all selene versions share one Roblox standard library cache, and an older selene cannot read the cache that a newer one wrote. Run selene from the project root, so that Rokit runs the version in `rokit.toml`.
17. **`selene .` reports thousands of errors:** it lints the Wally packages. Lint one file at a time.
