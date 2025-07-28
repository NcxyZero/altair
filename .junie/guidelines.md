# Development Guidelines

This document provides essential information for developers working on the project. It includes build/configuration instructions, testing guidelines, and other development information specific to this project.

## Build/Configuration Instructions

### Prerequisites

- [Roblox Studio](https://www.roblox.com/create) installed
- Git installed

### Initial Setup

1. Clone the repository:

   ```bash
   git clone <repository-url>
   cd <ProjectName>
   ```

2. Run the initialization script to install Aftman and other required tools:

   ```bash
   # On Windows
   ./init.sh

   # On macOS/Linux
   bash init.sh
   ```

   This script will:

   - Install Aftman (a tool manager for Roblox development)
   - Use Aftman to install project tools defined in aftman.toml
   - Update dependencies using Wally

### Project Structure

#### Defined in default.project.json

The project structure is defined in `default.project.json` as follows:

- `src/preload` → ReplicatedFirst
- `src/shared` → ReplicatedStorage.shared
- `src/util` → ReplicatedStorage.util
- `src/server` → ServerScriptService.server
- `ServerPackages` → ServerScriptService.server_package
- `src/client` → StarterPlayer.StarterPlayerScripts
- `Packages` → ReplicatedStorage.package (Wally packages)

#### Actual Project Structure

The actual structure of the project is:

- `src/`
  - `client/` - Client-side code
    - `init/` - Initialization scripts
    - `modules/` - Client modules
    - `main.client.luau` - Main client entry point
  - `server/` - Server-side code
    - `cmdr/` - Command scripts
    - `config/` - Server configuration
    - `modules/` - Server modules
    - `tests/` - Test scripts
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

2. **Serve the Project**: To sync your code with Roblox Studio, run:

   ```bash
   ./serve.sh
   ```

   If you have multiple project files, specify which one to serve:

   ```bash
   ./serve.sh <project-name>
   ```

3. **Open in Roblox Studio**: With the Rojo server running, connect to it from Roblox Studio using the Rojo plugin.

## Testing Information

### Testing Framework

The project uses a custom lightweight testing framework. Test files follow these conventions:

- Test files are placed in the `src/server/tests` directory or its subdirectories
- Test files are named with a `.spec.luau` suffix (e.g., `MathUtils.spec.luau`)
- Each test file should return `true` if all tests pass, or `false` if any test fails

### Running Tests

Tests are run using the TestRunner script located at `src/server/TestRunner.server.luau`. When the game starts in Roblox Studio, this script automatically:

1. Finds all test files (`.spec.luau`) in the `ServerScriptService.server.tests` folder
2. Runs each test and collects results
3. Outputs a summary of test results to the console

### Writing Tests

Here's an example of how to write a test file:

```luau
--!strict
-- MyModule.spec.luau
-- Test script for MyModule

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MyModule = require(ReplicatedStorage.shared.MyModule)

-- Simple test framework
local function expect<T1, T2>(value: T1): { [string]: (T2) -> (boolean) }
  return {
    toBe = function(expected: T2): boolean
      assert(value == expected, string.format("Expected %s to be %s", tostring(value), tostring(expected)))

      return true
    end,
    -- Add more matchers as needed
  }
end

-- Test cases
local function testMyFunction(): ()
  print("Testing MyModule.myFunction")
  expect(MyModule.myFunction(1, 2)).toBe(3)
  print("MyModule.myFunction tests passed!")
end

-- Run all tests
local function runAllTests(): boolean
  print("Starting MyModule tests...")

  local success, errorMessage = pcall(function(): ()
    testMyFunction()
    -- Add more test functions as needed
  end)

  if success then
    print("All MyModule tests passed!")
  else
    warn("Test failed: " .. errorMessage)
  end

  return success
end

-- Run the tests
return runAllTests()
```

### Adding New Tests

To add new tests:

1. Create a new module in the appropriate location (e.g., `src/shared/NewModule.luau`)
2. Create a corresponding test file in `src/server/tests` (e.g., `src/server/tests/NewModule.spec.luau`)
3. Follow the pattern shown above for writing tests
4. The TestRunner will automatically find and run your new test file

## Additional Development Information

### Code Style

- The project uses StyLua for code formatting
- Run StyLua before committing changes:

  ```bash
  stylua .
  ```

- Use type annotations for function parameters and return values
- Always specify return types for functions, use `()` for functions that return nothing
- Use `any`, `unknown`, or `never` when appropriate for types that can't be determined precisely
- Type local variables at declaration (except for game:GetService() and require() calls)
- Do not use section title comments in code (e.g., "-- Constants", "-- Private functions")
- Do not use the `pairs()` function in Luau code; use direct indexing or other iteration methods instead
- Do not use multiple statements in one line
- Do not use .Touched() event
- Do not use ValueBase instances, you can only use ObjectValue as attributes doesn't handle objects, still prefer to not use it
- Do not use the second argument in Instance.new(), it is deprecated. To set parent do this in new line after assigning other properties. The order of assigning properties is: Name, rest of properties in alphabetical order, Parent
- Prefer :FindFirstChildWhichIsA() over :FindFirstChildOfClass() unless necessary
- When declaring new variable and just after there is an "if" checking this variable, do not separate with blank line. Example:

```luau
local template: Folder = workspace:FindFirstChild("Template")
if not template then
  return
end
```

- Make blank lines between code blocks; above return keyword if it isn't the first line in block; when you create a new variable and assign its properties if should be together, when you switch to another variable it should be separated by blank line; separate lines where you assign values (including from calls) and not assigning call functions by blank lines. Separate calls on objects and the rest of calls. Example of all in this point:

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

- Do not leave unused variables, either add \_ at the beginning of the name or remove it
- Use Maid package for connections handling. Remember to use :DoCleaning() always when necessary to avoid memory leaks. Prefer :DoCleaning() over :Destroy() for style purposes as both function works the same way
- Follow the code organization pattern:
  1. Service imports at the top
  2. Module imports after services
  3. Instances (use :WaitForChild()) if present
  4. Type definitions, including the type for main table to return with the same name, including everything it does/can contains. Main table type needs to be always exported, rest when necessary. Main table type keys order (without empty lines, follow alphabetical order for every category):
     1. Functions (remember to include self: TypeName as a first argument if function cointains self)
     2. Tables (specify key type number if table isn't an array, for example there is table[0] = true)
     3. Primitive values
     4. Objects (specify descendants used in code if not necessary to add as a new main table entry)
     5. Maids, Signals, etc.
  5. Main table to return, example: local Module: Module = {} :: any
  6. Local variables and constants. In this order:
     1. Constants with comments, example: local DROP_TIME: number = 5 -- determines drop time
     2. Constant tables with comments line above
     3. Changeable variables with comments
     4. Changeable tables with comments
     5. Other variables without values set at this moment. If the given variable will always not be nil after setup on startup, do not add ? to the type, otherwise you can.
  7. Functions with proper type annotations
- Use "controller" terminology instead of "service" for game system modules

### Type Checking

- The project uses luau-lsp for type checking
- Run luau-lsp to check for type issues:

  ```bash
  luau-lsp analyze .
  ```

- The project also uses Selene for static analysis
- Run Selene to check for issues:

  ```bash
  selene .
  ```

- If you encounter persistent type errors that you can't resolve after several attempts:
  1. Try using more flexible types like `any` or union types
  2. Use type assertions when necessary (e.g., `value :: any`)
  3. If all else fails, you may skip typing for that specific case, but document why

### Linting

- The project uses Selene for static analysis
- Run Selene to check for issues:

  ```bash
  selene .
  ```

- For Markdown:
  1. Fenced code blocks, headings and lists should be surrounded by blank lines
  2. No multiple spaces after list markers
  3. Indent: 2 spaces as in .editorconfig
  4. Always specify fenced code language, including "text"
  5. Do not specify fenced code language as "lua", use "luau" instead

### Dependencies

- Dependencies are managed using Wally (defined in `wally.toml`)
- To add a new dependency:
  1. Add it to `wally.toml`
  2. Run `./update.sh` to install it
  3. The dependency will be available in the `Packages` directory

### State Management

- The project uses Reflex for state management
- Follow the Reflex patterns for creating stores, actions, and selectors

### Networking

- The project uses Bridgenet2 for networking
- Follow the established patterns for client-server communication

### Data Persistence

- The project uses ProfileService for data persistence
- Follow the established patterns for saving and loading player data

## Troubleshooting

### Common Issues

1. **Aftman not found**: Make sure to run `init.sh` and ensure that `~/.aftman/bin` is in your PATH
2. **Wally packages not found**: Run `./update.sh` to install dependencies
3. **Rojo connection issues**: Make sure the Rojo server is running (`./serve.sh`) and that you have the Rojo plugin installed in Roblox Studio
