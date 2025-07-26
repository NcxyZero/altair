# Client-Server Replication Guide

## Problem: Client-Side Changes Not Reflected on Server

We encountered an issue where changes made on the client side (using ClientDataTest) were not being reflected on the server side, and consequently not being saved when the player disconnected. The logs showed:

1. Server-side changes through DataTest were working correctly
2. Client-side changes through ClientDataTest were visible locally on the client
3. When the player disconnected, only the server-side changes were saved
4. The server was logging warnings: "Player tried to replicate secure reflex action secureAddCoins"

## Root Cause

The root cause was that the client was attempting to use a secure action (`secureAddCoins`) that is meant to be server-only. The server has a security mechanism that blocks any action with a name starting with "secure" when it comes from a client:

```lua
-- In ServerData.luau
local isSecureAction: number? = data.name:find("^secure")
if isSecureAction then
    warn("Player tried to replicate secure reflex action", data.name)
    return
end
```

This is a security feature to prevent clients from executing privileged actions that should only be performed by the server.

## Solution

The solution was to modify ClientDataTest.luau to use the regular `addCoins` action instead of the secure `secureAddCoins` action:

```lua
-- Before (not working)
producer.secureAddCoins(1)

-- After (working)
producer.addCoins(1)
```

The `addCoins` action is designed to be used by both clients and servers, while `secureAddCoins` is a server-only action that provides additional security for sensitive operations.

## Best Practices for Action Naming

To avoid similar issues in the future, follow these naming conventions:

1. **Regular Actions**: Use for operations that can be initiated by both clients and servers
   - Example: `addCoins`, `setCoins`, `removeInventoryItem`

2. **Secure Actions**: Prefix with "secure" for operations that should only be initiated by the server
   - Example: `secureAddCoins`, `secureSetCoins`, `secureRemoveInventoryItem`
   - These actions will be automatically blocked if a client tries to call them

3. **Client-Only Actions**: (Optional) Prefix with "client" for operations that are meant to be client-side only
   - Example: `clientUpdateUI`, `clientPlaySound`

## How Replication Works

1. **Client to Server**:
   - When a client dispatches an action, the replication middleware sends it to the server
   - The server checks if the action name starts with "secure"
   - If it's a secure action, it's rejected; otherwise, it's executed on the server

2. **Server to Client**:
   - When the server dispatches an action, it's sent to all relevant clients
   - Clients execute the action locally, setting `nextActionIsReplicated` to prevent infinite loops

This bidirectional replication ensures that state changes are synchronized between clients and the server, while maintaining security by preventing clients from executing privileged operations.
