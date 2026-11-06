# Creating Dependencies

This guide explains how to add a package to [altair-utils](https://github.com/NcxyZero/altair-utils) or create your own dependency repository that `require-dependency.sh` / `require-dependency.ps1` can install from.

## Repository Layout

A dependency repository is any git repository where each top-level folder is one package:

```text
my-utils/
  README.md
  Math/
    dependency.toml
    Clamp01.luau
    Smoothstep.luau
  Inventory/
    dependency.toml
    GetItemCount.luau
    Helpers/
      SortItems.luau
```

- The folder name is the package name users type, for example `bash require-dependency.sh Inventory`
- A folder counts as a package when it has a `dependency.toml` or contains at least one `.luau` file
- Folders starting with `.` are ignored
- Everything inside the folder except `dependency.toml` is copied to `src/util/<Package>`, including subfolders
- Packages can live in a subfolder of the repository; set `path` for that repository in `altair-dependencies.toml`

## The Manifest

`dependency.toml` is optional but recommended:

```toml
description = "Item counting and sorting helpers"
dependencies = ["Table"]
packages = ["Maid", "Promise"]
```

| Key | Description |
| --- | --- |
| `description` | One line shown by `--list` |
| `dependencies` | Other packages installed automatically together with this one, searched in every configured repository |
| `packages` | Wally packages the modules require; the installer warns when they are missing from `wally.toml` |

Keep every value on a single line.

## Writing Modules

- Follow the [development guidelines](../GUIDELINES.md), the same as for code inside Altair
- One module per `.luau` file, named after what it returns, for example `Clamp01.luau`
- Require other modules of the same package through the install path: `require(ReplicatedStorage.util.Math.Clamp01)`
- Require modules of other packages the same way and list those packages in `dependencies`
- Altair core utilities (see [Utility Dependencies](README.md#core-utilities)) can be required directly, for example `require(ReplicatedStorage.util.Core.Logger)`
- Wally packages are required from `ReplicatedStorage.package`, and must be listed in `packages`
- Do not name a package `Core`, that folder is reserved for Altair's core utilities

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetDictionaryLength = require(ReplicatedStorage.util.Table.GetDictionaryLength)

return function(inventory: { [string]: number }): number
	return GetDictionaryLength(inventory)
end
```

## Adding A Package To altair-utils

1. Create a folder named after the package in the altair-utils repository
2. Add the modules and a `dependency.toml`
3. Run `stylua` on the new files
4. Document the package in Altair at `docs/dependencies/<Package>.md` and add it to the table in [Utility Dependencies](README.md#packages-in-altair-utils)
5. Push the changes; projects get them the next time they run the installer

Moving a module from a project into a package works the same way: move the file into the package folder, change its requires from `ReplicatedStorage.util.<Module>` to `ReplicatedStorage.util.<Package>.<Module>` in every file that uses it, and only move modules Altair itself does not use.

## Testing A Package Locally

Point a repository entry at a local folder, commit your changes in it, and install:

```toml
[[repository]]
name = "my-utils-local"
url = "C:/Users/<user>/my-utils"
```

```bash
bash require-dependency.sh --list
bash require-dependency.sh --force Inventory
```

The installer clones repositories with git, so only committed files are installed. Then refresh the sourcemap if needed (`bash refresh-sourcemap.sh`) and type-check the installed files with luau-lsp, one file per command, as [Running luau-lsp](../GUIDELINES.md#running-luau-lsp) shows (for example `src/util/Inventory/GetItemCount.luau`).

## Adding A Repository To A Project

Add a `[[repository]]` entry to `altair-dependencies.toml`. Order matters: the first repository is option `1` in prompts and its files win when the same file name comes from several repositories.

```toml
[[repository]]
name = "my-utils"
url = "https://github.com/<user>/my-utils"
branch = "main"
```
