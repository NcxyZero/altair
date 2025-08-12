# Altair

A Roblox game project with a structured architecture, robust state management, networking, and data persistence.

## Overview

Altair is a Roblox game project that follows a modular architecture with controllers and modules. It uses a tag-based system for managing game objects and provides a structured framework for game development.

## Features

- Modular architecture with controllers and modules
- Tag-based system for game objects
- State management using Reflex
- Networking with Bridgenet2
- Data persistence with ProfileService

## Prerequisites

- [Roblox Studio](https://www.roblox.com/create) installed
- Git installed

## Getting Started

### Installation

1. Clone the repository:

    ```bash
    git clone <repository-url>
    cd <project-directory>
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

## Project Structure

### Defined in default.project.json

The project structure is defined in `default.project.json` as follows:

- `src/preload` → ReplicatedFirst
- `src/shared` → ReplicatedStorage.shared
- `src/util` → ReplicatedStorage.util
- `src/server` → ServerScriptService.server
- `ServerPackages` → ServerScriptService.server_package
- `src/client` → StarterPlayer.StarterPlayerScripts
- `Packages` → ReplicatedStorage.package (Wally packages)

### Actual Project Structure

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

## Documentation

Detailed documentation is available in the `docs/` directory:

- [Client Modules](docs/README_CLIENT_MODULES.md) — Documentation for client-side modules
- [Data Handling](docs/README_DATA_HANDLING.md) — Documentation for data handling in the project
- [Logger](docs/README_LOGGER.md) — Documentation for the logging system
- [Preload](docs/README_PRELOAD.md) — Documentation for preloading functionality
- [Reflex Producers](docs/README_REFLEX_PRODUCERS.md) — Documentation for Reflex producers (state management)
- [Server Modules](docs/README_SERVER_MODULES.md) — Documentation for server-side modules
- [Signals and Bridges](docs/README_SIGNALS_AND_BRIDGES.md) — Documentation for signals and bridges (networking)
- [Reflex Logger Guide](docs/REFLEX_LOGGER_GUIDE.md) — Guide for using the Reflex logger

## Development Guidelines

Comprehensive development guidelines are available in the `.junie/guidelines.md` file. These guidelines cover:

- Code style and organization
- Type checking and linting
- Dependency management
- State management
- Networking
- Data persistence
- Troubleshooting

## Testing

- Do not create test files in the project directory
- Use `luau-lsp.exe` to analyze files individually (do not analyze the entire workspace). Examples:

  ```text
  .\luau-lsp.exe analyze src\client\main.client.luau
  .\luau-lsp.exe analyze src\server\main.server.luau
  ```

- Run Selene for static analysis:

  ```bash
  selene .
  ```

- Important: After creating any new file, run `./update.sh` before analyzing with `luau-lsp.exe` to ensure all dependencies and project structure are updated
- For functionality verification, use the existing type checking tools (`luau-lsp.exe` and `selene`)

## Dependencies

The project uses the following main dependencies:

- BezierTweens — For smooth animation curves
- Bridgenet2 — For networking
- CameraShaker — For camera effects
- Cmdr — A command console for Roblox
- Fastcast — For raycasting/projectile simulation
- Maid — For managing connections and cleanup
- ProfileService — For data persistence
- Promise — For asynchronous operations (typed-promise)
- Reflex — For state management
- Signal — For event handling
- SimpleSpline — For spline calculations
- Lapis (server-only) — For server-side functionality

## Troubleshooting

### Common Issues

1. **Aftman not found**: Make sure to run `init.sh` and ensure that `~/.aftman/bin` is in your PATH
2. **Wally packages not found**: Run `./update.sh` to install dependencies
3. **Rojo connection issues**: Make sure the Rojo server is running (`./serve.sh`) and that you have the Rojo plugin installed in Roblox Studio

## License

See the [LICENSE](LICENSE) file for details.
