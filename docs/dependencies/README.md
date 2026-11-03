# Altair - Utility Dependencies

Altair ships its core utilities, in `src/util/Core`, and one installed package, `Effects`, because `SettingsUI` requires its `ClickRipple`. Everything else lives in separate dependency repositories (by default [altair-utils](https://github.com/NcxyZero/altair-utils)) and is installed on demand, so a fresh project stays small and only contains the utilities it actually uses.

## How It Works

- `altair-dependencies.toml` lists the repositories to search, in priority order
- Each top-level folder in a repository is one dependency (a package), for example `Math` or `Camera`
- `require-dependency.sh` (bash) or `require-dependency.ps1` (PowerShell) downloads the repositories, finds the requested packages and copies them into `src/util/<Package>`
- Rojo maps `src/util` to `ReplicatedStorage.util`, so installed modules are required as `ReplicatedStorage.util.<Package>.<Module>`
- `src/util` contains only folders: `Core` for the core utilities and one folder per installed package
- Installed files are plain source files in your project: commit them, edit them, or delete the folder to uninstall. Keep `src/util/Effects`: without it `SettingsUI` fails to load and the settings window never starts

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LerpNumber = require(ReplicatedStorage.util.Math.LerpNumber)

local value: number = LerpNumber(0, 10, 0.5)
```

## Installing Packages

Bash (macOS, Linux, Git Bash):

```bash
bash require-dependency.sh Math
bash require-dependency.sh Math Camera Audio
bash require-dependency.sh --list
```

PowerShell (Windows):

```powershell
.\require-dependency.ps1 Math
.\require-dependency.ps1 Math Camera Audio
.\require-dependency.ps1 -List
```

If PowerShell blocks the script, run it with `powershell -ExecutionPolicy Bypass -File .\require-dependency.ps1 Math`.

### Options

| Bash | PowerShell | Description |
| --- | --- | --- |
| `-l`, `--list` | `-List`, `-l`, `--list` | List packages available in every repository and mark installed ones |
| `-f`, `--force` | `-Force`, `-f`, `--force` | Reinstall already installed packages without asking |
| `-h`, `--help` | `-Help`, `-h`, `--help` | Show help |

Package names are case-insensitive (`math` finds `Math`).

### Package In Several Repositories

When a package exists in more than one repository, the script shows each one with a number and asks which to install from:

```text
"Math" was found in 2/3 repositories:
  1) altair-utils (https://github.com/NcxyZero/altair-utils)
  2) my-utils (https://github.com/<user>/my-utils)
Select repositories to install from (for example "1 2"), Enter for 1:
```

- `1 2` installs from repositories 1 and 2
- `2` installs only from repository 2
- Enter installs from repository 1

When several repositories are chosen, their files are merged into the same `src/util/<Package>` folder. If two repositories contain a file with the same name, the one from the repository typed first is kept and the other is skipped with a warning.

### Reinstalling

Requesting a package that is already installed asks before replacing its folder. Use `--force` / `-Force` to skip the question. Packages pulled in as dependencies of another package are never reinstalled automatically.

### After Installing

- The script refreshes `sourcemap.json` when `rojo` is available
- It warns when a package needs a Wally package that is missing from `wally.toml`; add it and run `bash update.sh`
- Packages listed in a package's `dependencies` are installed automatically

## Configuration

`altair-dependencies.toml` in the project root:

```toml
install-path = "src/util"

[[repository]]
name = "altair-utils"
url = "https://github.com/NcxyZero/altair-utils"
branch = "main"

[[repository]]
name = "my-utils"
url = "https://github.com/<user>/my-utils"
```

| Key | Required | Description |
| --- | --- | --- |
| `install-path` | no | Folder where packages are installed, defaults to `src/util` |
| `name` | no | Label shown in prompts, defaults to the last part of `url` |
| `url` | yes | Any git URL or local path |
| `branch` | no | Branch or tag to use, defaults to the remote's default branch |
| `path` | no | Folder inside the repository that holds the packages, defaults to the repository root |

If the file is missing, only `altair-utils` is used. Only single-line values are supported.

## Core Utilities

These are always part of Altair, live in `src/util/Core` and are required as `ReplicatedStorage.util.Core.<Module>`, because Altair itself uses them. `Core` is reserved and cannot be installed as a package:

`AssetPreloader`, `BuildStockConfig`, `CalculateTargetMass`, `CanSendGameInvite`, `ConvertCurrency`, `ConvertHexToInt`, `ConvertToSentenceCase`, `ConvertToTextTime`, `CreateInstance`, `CreatePrompt`, `DeepClone`, `EscapeRichText`, `GetBridge`, `GetFunctionBridge`, `GetInstanceCFrame`, `GetSignal`, `IsPlayerOnMobile`, `IsValidUTF8`, `LocalPlayer`, `Logger`, `MergeDictionaries`, `OpenGui`, `PlayerGui`, `SFX`, `SecurePlayerAsync`, `SetCharacterControlsEnabled`, `SetInstanceCFrame`, `WaitForGameToLoad`, `WithoutPlayer`

Altair also ships the [Effects](Effects.md) package, installed in `src/util/Effects` like any other package, because `SettingsUI` requires `ReplicatedStorage.util.Effects.ClickRipple`. `bash require-dependency.sh --force Effects` reinstalls it.

## Packages In altair-utils

| Package | Contents |
| --- | --- |
| [Async](Async.md) | Promise wrappers and helpers that wait for elements, tags, producer changes and bridge responses |
| [Audio](Audio.md) | Sound playback helpers with random picks and fades |
| [Camera](Camera.md) | Camera nudge and shake effects |
| [Character](Character.md) | Character lookup, movement, teleport and safe character access |
| [Effects](Effects.md) | Click ripples, confetti and overhead text |
| [Geometry](Geometry.md) | Closest-part searches and point/part containment checks |
| [Math](Math.md) | Interpolation, mapping, curves, bezier points and springs |
| [Misc](Misc.md) | Enum lookup, switch statement and Studio instance action helpers |
| [Physics](Physics.md) | Model mass and welding helpers |
| [Player](Player.md) | Player launch data, favorites, console detection and haptics |
| [Random](Random.md) | Random numbers, weighted picks and random positions |
| [String](String.md) | Case conversion, number formatting and string tag replacement |
| [Table](Table.md) | Table lookup, length, keys, values and array merging |
| [Time](Time.md) | Display time formatting, day ids, time until midnight and timeouts |
| [UI](UI.md) | Anchor point adjustments, typewriter text and number tweens |

To create your own packages or repositories, see [Creating Dependencies](CREATING_DEPENDENCIES.md).
