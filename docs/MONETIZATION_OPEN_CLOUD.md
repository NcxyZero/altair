# Roblox Open Cloud monetization

This document defines the safe workflow for Roblox monetization operations made
by an AI agent from a terminal. It can be reused across projects and must not
contain universe, place, group, product, or pass IDs copied from another game.

## Required identifiers and confirmation

`game.GameId` is the universe ID used by the endpoints below. It is not the same
as `game.PlaceId`.

Before reading or changing monetization resources, the agent must establish the
target universe. First inspect the project's `GameConfig` for its configured
public universe ID. In this codebase the value is
`GameConfig.game.publicGame.universeId`. A missing value or `0` means "not
configured" and must never be sent to Roblox.

If the user did not provide an ID, tell them which of these sources are actually
available and ask which one to use:

- The nonzero public universe ID found in `GameConfig`, showing the candidate
  numeric ID for confirmation.
- `game.GameId` from the currently open experience when Roblox Studio MCP is
  connected.
- A universe ID supplied manually by the user.

Do not offer `GameConfig` as a usable source when its value is absent or `0`. Do
not claim Studio as a source when Studio MCP is unavailable.

Do not silently choose among the available sources or infer the universe from
an adjacent repository, an old response, a place ID, or a group ID. Before any
mutating request, show the selected target universe ID and intended resource
values to the user and obtain confirmation.

With permission, Studio can return the relevant identity values with an
equivalent of:

```luau
return {
  creatorId = game.CreatorId,
  creatorType = game.CreatorType.Name,
  gameId = game.GameId,
  placeId = game.PlaceId,
}
```

When `creatorType` is `Group`, `creatorId` is the group ID. It is ownership
metadata, not a replacement for `gameId`.

## API key

The terminal workflow reads the Open Cloud key from the environment variable
`RobloxMonetization` and sends it as the `x-api-key` request header. Never print,
log, commit, or include the key in a tool argument or chat response.

Check whether the variable exists without revealing its value.

PowerShell on Windows:

```powershell
Test-Path Env:RobloxMonetization
```

macOS:

```bash
if [[ -n "${RobloxMonetization:-}" ]]; then echo "configured"; else echo "missing"; fi
```

If the agent cannot access the variable, it must stop before calling the API and
either explain the Windows setup below or ask the user to create the ignored
`.env` file and paste the key there. The user must enter the secret themselves.

Set the variable for the current PowerShell session:

```powershell
$robloxMonetizationSecret = Read-Host "Roblox Open Cloud key" -AsSecureString
$env:RobloxMonetization = [System.Net.NetworkCredential]::new("", $robloxMonetizationSecret).Password
Remove-Variable robloxMonetizationSecret
```

Persist it for the current Windows user, then restart the terminal and any MCP
process that needs it:

```powershell
$robloxMonetizationSecret = Read-Host "Roblox Open Cloud key" -AsSecureString
$robloxMonetizationKey = [System.Net.NetworkCredential]::new("", $robloxMonetizationSecret).Password
[Environment]::SetEnvironmentVariable("RobloxMonetization", $robloxMonetizationKey, "User")
Remove-Variable robloxMonetizationKey, robloxMonetizationSecret
```

Alternatively, create `.env` in the repository root. It is already ignored by
Git:

```dotenv
RobloxMonetization=PASTE_KEY_HERE
```

Load that file into PowerShell without displaying the key:

```powershell
$robloxMonetizationLine = Get-Content .env | Where-Object { $_ -match '^RobloxMonetization=' } | Select-Object -First 1
if ($null -eq $robloxMonetizationLine) { throw "RobloxMonetization is missing from .env" }
$env:RobloxMonetization = $robloxMonetizationLine.Substring("RobloxMonetization=".Length)
Remove-Variable robloxMonetizationLine
```

Load the same file on macOS:

```bash
set -a
source .env
set +a
```

## Developer product request

Creating a developer product uses this contract:

- Method: `POST`
- URL:
  `https://apis.roblox.com/developer-products/v2/universes/{universeId}/developer-products`
- Authentication header: `x-api-key`
- Body: `multipart/form-data`
- Known form fields: `name`, `description`, `isForSale`, `price`, and
  `isManagedPricingEnabled`

Replace every placeholder and obtain confirmation before executing it. Enable
regional pricing by sending `isManagedPricingEnabled=true` unless the user
explicitly requests an exception. The former `isRegionalPricingEnabled` field
is deprecated and can be ignored by Roblox. Verify the created resource with a
creator `GET`; a successful response should report
`priceInformation.enabledFeatures` containing `RegionalPricing`.

If Roblox returns `InvalidManagedPricing` with "Managed pricing must be
accepted before it can be enabled", the experience owner must complete the
initial onboarding in Creator Hub under Monetization > Managed Pricing.
The failed create does not establish a product ID. Do not silently disable
Managed Pricing or substitute the deprecated regional-pricing field; obtain
the user's explicit exception before creating without Managed Pricing.

The creator verification endpoint for one product is:

`GET https://apis.roblox.com/developer-products/v2/universes/{universeId}/developer-products/{productId}/creator`

PowerShell on Windows uses `curl.exe` explicitly because `curl` can be an alias
in some PowerShell versions:

```powershell
$universeId = "UNIVERSE_ID"
curl.exe --request POST `
  --url "https://apis.roblox.com/developer-products/v2/universes/$universeId/developer-products" `
  --header "x-api-key: $env:RobloxMonetization" `
  --form-string "name=PRODUCT_NAME" `
  --form-string "description=PRODUCT_DESCRIPTION" `
  --form-string "isForSale=true" `
  --form-string "price=PRICE_IN_ROBUX" `
  --form-string "isManagedPricingEnabled=true"
```

macOS:

```bash
universe_id="UNIVERSE_ID"
curl --request POST \
  --url "https://apis.roblox.com/developer-products/v2/universes/${universe_id}/developer-products" \
  --header "x-api-key: ${RobloxMonetization}" \
  --form-string "name=PRODUCT_NAME" \
  --form-string "description=PRODUCT_DESCRIPTION" \
  --form-string "isForSale=true" \
  --form-string "price=PRICE_IN_ROBUX" \
  --form-string "isManagedPricingEnabled=true"
```

An equivalent generic MCP request payload is:

```json
{
  "url": "https://apis.roblox.com/developer-products/v2/universes/UNIVERSE_ID/developer-products",
  "method": "POST",
  "form": {
    "name": "PRODUCT_NAME",
    "description": "PRODUCT_DESCRIPTION",
    "isForSale": true,
    "price": "PRICE_IN_ROBUX",
    "isManagedPricingEnabled": true
  }
}
```

### Updating a developer product

Use `PATCH https://apis.roblox.com/developer-products/v2/universes/{universeId}/developer-products/{productId}`
with the `x-api-key` header, the `developer-product:write` scope, and a
`multipart/form-data` body. For a rename, send only the `name` field. The
expected successful status is `204`. Then read the creator resource above
and verify the new name plus preservation of the other configuration fields.
See the [official developer-product API reference](https://create.roblox.com/docs/cloud/reference/features/developer-products).

## Game pass request

Creating a game pass uses this contract:

- Method: `POST`
- URL:
  `https://apis.roblox.com/game-passes/v1/universes/{universeId}/game-passes`
- Authentication header: `x-api-key`
- Body: `multipart/form-data`
- Required form field: `name`
- Optional form fields include `description`, `imageFile`, `isForSale`, `price`,
  and `isManagedPricingEnabled`

As with developer products, send `isManagedPricingEnabled=true` by default and
verify the creator response before recording the returned pass ID.

Reading one known game pass uses this contract:

- Method: `GET`
- URL:
  `https://apis.roblox.com/game-passes/v1/universes/{universeId}/game-passes/{passId}/creator`
- Authentication header: `x-api-key`

PowerShell on Windows:

```powershell
$universeId = "UNIVERSE_ID"
$passId = "PASS_ID"
curl.exe --request GET `
  --url "https://apis.roblox.com/game-passes/v1/universes/$universeId/game-passes/$passId/creator" `
  --header "x-api-key: $env:RobloxMonetization"
```

macOS:

```bash
universe_id="UNIVERSE_ID"
pass_id="PASS_ID"
curl --request GET \
  --url "https://apis.roblox.com/game-passes/v1/universes/${universe_id}/game-passes/${pass_id}/creator" \
  --header "x-api-key: ${RobloxMonetization}"
```

An equivalent generic MCP request payload is:

```json
{
  "url": "https://apis.roblox.com/game-passes/v1/universes/UNIVERSE_ID/game-passes/PASS_ID/creator",
  "method": "GET"
}
```

Updating a game pass uses this contract:

- Method: `PATCH`
- URL:
  `https://apis.roblox.com/game-passes/v1/universes/{universeId}/game-passes/{passId}`
- Authentication header: `x-api-key`
- Required scope: `game-pass:write`
- Body: `multipart/form-data`
- Optional form fields include `name`, `description`, `imageFile`, `isForSale`,
  `price`, and `isManagedPricingEnabled`
- Expected successful status: `204`

Only send fields intended to change. After the `204`, always read the creator
resource above and verify every requested value because Roblox documents that
insufficiently scoped keys can appear successful without applying a mutation.
This document does not define a delete contract; verify current official Roblox
Open Cloud documentation before attempting deletion.

## Response handling

- Treat only an expected successful HTTP status as success; preserve the status
  and response body for diagnosis, but redact secrets.
- Record newly returned product/pass IDs in the appropriate project
  configuration only when the implementation task requires it.
- Never retry a mutating request blindly after a timeout or ambiguous response.
  First query Roblox to determine whether the resource was already created.
- A `401` or `403` should lead to checking the key's Open Cloud scopes, target
  universe permissions, ownership, and expiration. Do not expose the key while
  diagnosing it.
