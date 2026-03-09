# Development Guidelines

This document provides essential information for developers working on the project. It includes build/configuration instructions, testing guidelines, and other development information specific to this project.

Project guidelines take priority over any assistant modes or operational workflows that might otherwise request conflicting actions.

## Build/Configuration Instructions

### Prerequisites

- **[Roblox Studio](https://www.roblox.com/create)** installed
- **Git** installed

### Initial Setup

1. Clone the repository:

   ```bash
   git clone <repository-url>
   cd <ProjectName>
   ```

2. Run the initialization script to install the tool manager and other required tools:

   ```bash
   # On Windows
   ./init.sh

   # On macOS/Linux
   bash init.sh
   ```

   This script will:

- Install `Rokit` when `rokit.toml` exists or `Aftman` when `aftman.toml` exists
- Use the matching tool manager to install project tools defined in that file
- Update dependencies using `Wally`

### Project Structure

#### Defined in `default.project.json`

The project structure is defined in `default.project.json` as follows:

- `src/preload` → ReplicatedFirst
- `src/shared` → ReplicatedStorage.shared
- `src/util` → ReplicatedStorage.util
- `src/server` → ServerScriptService.server
- `src/client` → ReplicatedStorage.client
- `Packages` → ReplicatedStorage.package (Wally packages)
- `ServerPackages` → ServerScriptService.server_package (Wally server packages)

#### Actual Project Structure

The actual structure of the project is:

- `src/`
  - `client/` - Client-side code
    - `clientConfig/` - Client configuration
    - `modules/` - Client modules
    - `ui/` - User interface components
    - `main.client.luau` - Main client entry point
  - `server/` - Server-side code
    - `cmdr/` - Command scripts
    - `config/` - Server configuration
    - `modules/` - Server modules
    - `serverConfig/` - Server configuration
    - `main.server.luau` - Main server entry point
  - `shared/` - Code shared between client and server
    - `config/` - Shared configuration
    - `model/` - Data models
    - `reflex/` - Reflex state management
    - `types/` - Type definitions
  - `util/` - Utility functions
- `Packages/` - Client and shared Wally packages
- `ServerPackages/` - Server-only Wally packages

### Development Workflow

1. **Update Dependencies**: After pulling changes, run the update script to ensure all dependencies are up to date:

   ```bash
   ./update.sh
   ```

2. **Serve the Project**: To sync your code with `Roblox Studio`, run:

   ```bash
   ./serve.sh
   ```

   If you have multiple project files, specify which one to serve:

   ```bash
   ./serve.sh <project-name>
   ```

3. **Open in `Roblox Studio`**: With the `Rojo` server running, connect to it from `Roblox Studio` using the `Rojo` plugin.

## Additional Development Information

### Code Style

- The project uses `StyLua` for code formatting
- Run `StyLua` before committing changes:

  ```bash
  stylua .
  ```

- Do not remove unrelated changes when cleaning up before a commit

- Use type annotations for function parameters and return values, for example: `local function foo(bar: string): boolean`, use `()` for functions that return nothing
- Use `any`, `unknown`, or `never` when appropriate for types that can't be determined precisely
- Type local variables at declaration (except for `game:GetService()` and `require()` calls)
- Do not use section title comments in code (e.g., "-- Constants", "-- Private functions")
- Do not use the `pairs()` function in Luau code; use direct indexing or other iteration methods instead
- Use direct string methods instead of string library functions (e.g., use `text:split("")` instead of `string.split(text, "")`)
- When formatting strings with backticks in Luau, use `{}` directly without `$`; `${}` would appear literally because Luau already interpolates
- Use integer division (`//`) instead of regular division with `math.floor()` (e.g., use `value // 2` instead of `math.floor(value / 2)`)
- Do not use multiple statements in one line
- Do not use `.Touched()` event
- Do not use `ValueBase` instances, you can only use `ObjectValue` as attributes doesn't handle objects, still prefer to not use it
- Do not use the second argument in `Instance.new()`, it is deprecated. To set parent do this in a new line after assigning other properties. The order of assigning properties is: `Name`, rest of properties in alphabetical order, `Parent`
- Do not use `.Chatted` event, it doesn't work with new Roblox chat. Use `TextChatService` instead
- Do not create a chat command when the command is not specified to be for chat, then assume you are asked to create the Cmdr command
- Do not use `SetPrimaryPartCFrame()` as it is deprecated, always use `PivotTo()`, `GetPivot()`, `ScaleTo()` and `GetScale()` instead
- Use `UDim2.fromScale()` and `UDim2.fromOffset()` instead of `UDim2.new()` when you are not setting both scale and offset
- Use `Color3.new()` instead of `Color3.fromRGB(0, 0, 0)` as zeros are the default values
- Use `CFrame.identity` instead of `CFrame.new(0, 0, 0)` or `CFrame.new()` as zeros are the default values
- Use `CFrame.fromAxisAngle()` instead of `CFrame.Angles()` in case of only one axe not being zero
- Use `Vector2`'s and `Vector3`'s `.xAxis`, `.yAxis`, and `Vector3`'s `.zAxis` in `CFrame.fromAxisAngle()` and in case of only one axe not being zero, example: `Vector2.yAxis * 5`
- Use `Vector2`'s and `Vector3`'s `.zero` and `.one` instead of `.new()`, `.new(0, 0, 0)` and `.new(1, 1, 1)`
- Use `Vector2`'s and `Vector3`'s `.one` when all axes are the same (e.g., use `Vector3.one * 5` instead of `Vector3.new(5, 5, 5)`)
- Always use compound assignments (for example, `%=, ..=, //=')
- Prefer `os.clock()` and `DateTime` library for time
- Do not add `--!strict` at the top of files, but also do not remove it when already present, and do not describe a file on top
- Prefer `:FindFirstChildWhichIsA()` over `:FindFirstChildOfClass()` unless necessary
- When declaring new variable and just after there is an `if` checking this variable, do not separate with blank line.

Example:

```luau
local template: Folder = workspace:FindFirstChild("Template")
if not template then
  return
end
```

- Make blank lines between code blocks and above `return`/`break`/`continue` keywords if it isn't the first line in the block; when you create a new variable and assign its properties, it should be together, when you switch to another variable, it should be separated by blank line; separate lines where you assign values (including from calls) and not assigning call functions by blank lines. Separate calls on objects and the rest of calls. Example of all in this point:

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

- Use bare `return` instead of `return nil`; only use `return nil` when returning additional values after `nil` (for example, `return nil, false`)
- Do not leave unused variables, either add `_` at the beginning of the name or remove it
- Use `Maid` package for connection handling. Remember to use `:DoCleaning()` always when necessary to avoid memory leaks. Prefer `:DoCleaning()` over `:Destroy()` for style purposes as both functions are aliases for the one very same function
- Follow the code organization pattern:
  1. Service imports at the top
  2. Module imports after services
  3. Instances (use `:WaitForChild()`) if present
  4. Type definitions, including the type for the main table to return with the same name, including everything it does/can contain. The main table type needs to be always exported, rest when necessary. Main table type keys order (without empty lines, follow alphabetical order for every category):
     1. Functions (remember to include `self: TypeName` as a first argument if function contains `self`)
     2. Tables (specify key type number if table isn't an array, for example, there is `table[0] = true`)
     3. Primitive values
     4. Objects (specify descendants used in code if not necessary to add as a new main table entry)
     5. `Maid`s, `Signal`s, etc.
  5. Main table to return, example: `local Module: Module = {} :: any`
  6. Local variables and constants. In this order:
     1. Constants with comments, example: `local DROP_TIME: number = 5 -- determines drop time`
     2. Constant tables with the comment line above
     3. Changeable variables with comments
     4. Changeable tables with comments
     5. Other variables without values are set at this moment. If the given variable always not are nil after setup on startup, do not add `?` to the type, otherwise you can
  7. Functions with proper type annotations
- Use "controller" terminology instead of "service" for game system modules
- Controller modules with `Init()` function should be initialized only by `main.client.luau` / `main.server.luau`, not by other modules
- Do not call module's `Init()` function at the end of the module itself
- Do not use abbreviations in variable names — use full, descriptive names for readability (e.g., use `player` instead of `plr`, `callback` instead of `cb`, `connection` instead of `conn`)
- Prefer using `and`/`or` logical operators instead of `if-else` statements when appropriate for cleaner, more readable code
- Do not declare `local function` inside other functions; define methods on `self` instead to keep behavior organized and consistent
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

### Type Checking

- The project uses `luau-lsp` for type checking
- The `luau-lsp.exe` executable is available in the project root directory
- Note: `luau-lsp.exe analyze` is not fully configured with Roblox definitions in all environments. It may report noisy errors like `Unknown global 'game'` / unknown Roblox types or requires
  - Ignore that noise and use `luau-lsp` as a best-effort checker for obvious, real issues in the file (syntax errors, incorrect types in your own code, etc.)
  - Do not spend time trying to fix the missing Roblox definitions/setup as part of normal development tasks
- **Important**: Do not use `./luau-lsp.exe analyze .` to analyze all files at once as this causes "Failed to build..." errors
- **Important**: `luau-lsp.exe analyze` should be run on a single file path only. Do not pass folders (e.g. `src`), do not pass multiple file paths in one command, and do not batch it with `foreach`/loops — run it once per file.
- Instead, analyze files individually:

  ```bash
  ./luau-lsp.exe analyze path/to/file.luau
  ```

  For example:

  ```bash
  ./luau-lsp.exe analyze src/client/modules/ClientInventory.luau
  ./luau-lsp.exe analyze src/server/modules/ServerInventory.luau
  ```

- **Important**: Do not run `selene .` as it is not supported in this project environment. Instead, analyze files individually:

  ```bash
  selene path/to/file.luau
  ```

- If you encounter persistent type errors that you can't resolve after several attempts:
  1. Try using more flexible types like `any` or union types
  2. Use type assertions when necessary (e.g., `value :: any`)
  3. If all else fails, you may skip typing for that specific case, but document why

### Testing

- **Do not create test files** in the project directory
- **Do not create debug scripts** in the project directory for testing or debugging purposes
- Use `luau-lsp.exe` for type checking and validation instead of creating separate test scripts
- **Important**: When any new file has been created, the Rojo `sourcemap.json` must include it for correct editor IntelliSense and `luau-lsp` resolution.
  - Quick fix (refresh sourcemap only): `bash refresh-sourcemap.sh`
  - Full update (dependencies + sourcemap + generated types): `bash update.sh`
  - Optional (Windows): keep sourcemap up to date automatically with `bash watch-sourcemap.sh`
- For functionality verification:
  1. Use the existing type checking tools (`luau-lsp.exe` and `selene`)
  2. Test functionality directly in `Roblox Studio` during development
  3. Use the build system to verify compilation success

### Linting

- **Important**: Do not run `selene .` as it is not supported in this project environment. Instead, analyze files individually: `selene path/to/file.luau`

- For `Markdown`:
  1. Blank lines should surround fenced code blocks, headings, and lists
  2. No multiple spaces after list markers
  3. Indent: two spaces as in `.editorconfig`
  4. Always specify fenced code language, including `text`
  5. Do not specify fenced code language as `lua`, use `luau` instead

### Dependencies

- Dependencies are managed using `Wally` (defined in `wally.toml`)
- To add a new dependency:
  1. Add it to `wally.toml`
  2. Run `./update.sh` to install it
  3. The dependency will be available in the `Packages` directory

### State Management

- The project uses `Reflex` for state management
- Follow the `Reflex` patterns for creating stores, actions, and selectors
- **Producer Action Patterns**: When using combined producers (created with `Reflex.combineProducers`), all actions from any profile are available at the producer root level
  - **Correct**: `producer.setHotbarItem(slot, itemId)`
  - **Incorrect**: `producer.inventory_setHotbarItem(slot, itemId)` or `producer.inventory.setHotbarItem(slot, itemId)`
  - Do not use prefixed action names like `producer.inventory_actionName` - all actions should be called directly on the producer root
- **Connection Management**: Always use `Maid` for handling GUI connections and other cleanup tasks
  - Use `self.maid:GiveTask(connection)` instead of manual connection management
  - Avoid storing individual connections as properties when Maid can handle them directly

### Networking

- The project uses `Bridgenet2` for networking
- Follow the established patterns for client-server communication

### Data Persistence

- The project uses `ProfileService` for data persistence
- Follow the established patterns for saving and loading player data

## Troubleshooting

### Common Issues

1. **`Rokit`/`Aftman` not found**: Make sure to run `init.sh` and ensure that `~/.rokit/bin` (Rokit) or `~/.aftman/bin` (Aftman) is in your PATH
2. **`Wally` packages not found**: Run `./update.sh` to install dependencies
3. **`Rojo` connection issues**: Make sure the `Rojo` server is running (`./serve.sh`) and that you have the `Rojo` plugin installed in `Roblox Studio`
