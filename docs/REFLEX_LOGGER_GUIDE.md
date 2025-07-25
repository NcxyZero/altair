# Logging Reflex Producer Actions with Logger Utility

This guide explains how to use the Logger utility to log data changes when using Reflex producers in the Altair project.

## Overview

The Altair project uses Reflex for state management and provides a simple Logger utility for debugging in Studio mode. By combining these tools, you can effectively track state changes and debug your application.

## Logger Utility

The Logger utility (`ReplicatedStorage.util.Logger`) provides simple logging functions that only work in Studio mode:

```luau
local Logger = require(ReplicatedStorage.util.Logger)

Logger.print("Example message")  -- Prints a message
Logger.warn("Warning message")   -- Prints a warning
Logger.error("Error message")    -- Throws an error
Logger.assert(condition, "Message if condition is false")  -- Asserts a condition
```

These functions are safe to use in production code as they only execute in Studio mode.

## Creating a Logger Middleware for Reflex

To log Reflex producer actions and state changes, you can create a custom middleware:

```luau
local function createLoggerMiddleware()
    return function(producer)
        -- Log initial state when middleware is mounted
        Logger.print("[Reflex-Logger]: Mounted with state " .. tostring(producer:getState()))

        -- Subscribe to state changes
        producer:subscribe(function(state)
            Logger.print("[Reflex-Logger]: State changed to " .. tostring(state))
        end)

        -- Log actions when dispatched
        return function(dispatch, name)
            return function(...)
                local arguments = table.pack(...)
                local argStrings = {}

                for index = 1, arguments.n do
                    table.insert(argStrings, tostring(arguments[index]))
                end

                Logger.print("[Reflex-Logger]: Dispatching " .. name .. "(" .. table.concat(argStrings, ", ") .. ")")

                return dispatch(...)
            end
        end
    end
end
```

## Applying the Logger Middleware

### Server-Side

To apply the logger middleware to a server-side producer:

```luau
local ServerData = require(script.Parent.modules.ServerData)
local producer = ServerData.gameProducer

-- Apply the logger middleware
producer:applyMiddleware(createLoggerMiddleware())

-- Now all actions and state changes will be logged
producer.incrementActivePlayers()  -- This will be logged
```

### Client-Side

To apply the logger middleware to a client-side producer:

```luau
local ClientData = require(script.Parent.Parent.modules.ClientData)

-- Wait for player data to load
ClientData:getPlayerProducerAsync():andThen(function(producer)
    -- Apply the logger middleware
    producer:applyMiddleware(createLoggerMiddleware())

    -- Now all actions and state changes will be logged
    producer.player_addCoins(25)  -- This will be logged
end)
```

## Example: Logging Player Profile Actions

```luau
local playerProfile = require(ReplicatedStorage.shared.reflex.playerProfile)

-- Create a player profile producer
local producer = playerProfile.CreateProducer({
    userId = 12345,
    coins = 100,
    inventory = {},
    settings = {
        musicVolume = 0.5,
        sfxVolume = 0.5,
    }
})

-- Apply the logger middleware
producer:applyMiddleware(createLoggerMiddleware())

-- Perform actions (these will be logged)
producer.addCoins(50)
producer.setInventoryItem("apple", 5)
producer.setSetting("musicVolume", 0.7)
```

## Example: Logging Game Profile Actions

```luau
local gameProfile = require(ReplicatedStorage.shared.reflex.gameProfile)

-- Create a game profile producer
local producer = gameProfile.CreateProducer({
    serverStartTime = os.time(),
    activePlayers = 0
})

-- Apply the logger middleware
producer:applyMiddleware(createLoggerMiddleware())

-- Perform actions (these will be logged)
producer.incrementActivePlayers()
producer.setActivePlayers(5)
```

## Best Practices

1. **Only Use for Debugging**: Remember that the Logger only works in Studio mode, so it's meant for debugging only.

2. **Apply Early**: Apply the logger middleware as early as possible after creating or accessing a producer to catch all actions.

3. **Be Selective**: For complex applications, consider only applying the logger middleware to specific producers you're debugging to avoid console clutter.

4. **Custom Formatting**: Modify the middleware to format the output in a way that's most useful for your specific debugging needs.

5. **Combine with Breakpoints**: Use the logged information alongside Studio breakpoints for more effective debugging.

## Troubleshooting

- If you're not seeing any logs, make sure you're running in Studio mode.
- Verify that the middleware is being applied to the correct producer.
- Check that you're using the correct action names when dispatching actions.

## Complete Example

See the test scripts for complete examples:
- `src/server/tests/LoggerTest.spec.luau` - Server-side test
- `src/client/init/LoggerClientTest.client.luau` - Client-side test
- `src/server/LoggerTestRunner.server.luau` - Test runner
