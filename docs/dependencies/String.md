# String

UTF-8 aware case conversion with Polish diacritics support, number formatting with thousands separators, and replacement of local player tags in text.

## Installation

```bash
bash require-dependency.sh String
```

```powershell
.\require-dependency.ps1 String
```

Installed into `src/util/String`, required as `ReplicatedStorage.util.String.<Module>`.

## Requirements

- Wally packages: none
- Core utils: none
- Other packages: none

## Modules

Common notes for the `ConvertTo*` modules:

- Besides ASCII, only the Polish letters `ą ć ę ł ń ó ś ź ż` (and their uppercase forms) have case mappings. Other non-ASCII characters are left unchanged.
- `replaceWhitespaceWith` only replaces the plain space character `" "`. Tabs and newlines stay as they are. If you leave it out, spaces are kept.
- They return the result of a `gsub` chain directly, so they actually return two values: the string and a replacement count. Plain `local` assignment drops the count, but wrap the call in parentheses when you pass it straight into another function (for example `table.insert(list, (ConvertToUppercase(text)))`).

### `ConvertToCamelCase`

Splits `input` into words (runs of non-whitespace characters). The first character of the first word is lowercased and the first character of every later word is uppercased. If `lowerRest` is truthy, the rest of each word goes through `string.lower`, which only lowercases ASCII. The words keep their spaces unless you pass `replaceWhitespaceWith`, so pass `""` to get real camelCase.

```luau
function ConvertToCamelCase(input: string, lowerRest: boolean?, replaceWhitespaceWith: string?): string
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConvertToCamelCase = require(ReplicatedStorage.util.String.ConvertToCamelCase)

local key: string = ConvertToCamelCase("Player Max Health", true, "")
```

### `ConvertToLowercase`

Lowercases `input` one UTF-8 character at a time, using the Polish mapping first and `string.lower` for everything else, then replaces spaces with `replaceWhitespaceWith` (default `" "`).

```luau
function ConvertToLowercase(input: string, replaceWhitespaceWith: string?): string
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConvertToLowercase = require(ReplicatedStorage.util.String.ConvertToLowercase)

local slug: string = ConvertToLowercase("ŻÓŁTY Smok", "-")
```

### `ConvertToPlainLowercase`

Changes Polish letters to their plain ASCII forms (`ą` to `a`, `Ł` to `l`, and so on), lowercases the result and replaces every space with `_`. The separator is fixed and there are no options. Useful for building ids from display names.

```luau
function ConvertToPlainLowercase(input: string): string
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConvertToPlainLowercase = require(ReplicatedStorage.util.String.ConvertToPlainLowercase)

local id: string = ConvertToPlainLowercase("Żółta Łódź")
```

### `ConvertToTitleCase`

Uppercases the first character of every word (runs of non-whitespace), using the Polish mapping or `string.upper`. If `lowerRest` is truthy, the rest of each word is lowercased with `string.lower` (ASCII only). Spaces are then replaced with `replaceWhitespaceWith` (default `" "`).

```luau
function ConvertToTitleCase(input: string, lowerRest: boolean?, replaceWhitespaceWith: string?): string
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConvertToTitleCase = require(ReplicatedStorage.util.String.ConvertToTitleCase)

local title: string = ConvertToTitleCase("the GOLDEN sword", true)
```

### `ConvertToUppercase`

Uppercases `input` one UTF-8 character at a time, using the Polish mapping first and `string.upper` for everything else, then replaces spaces with `replaceWhitespaceWith` (default `" "`).

```luau
function ConvertToUppercase(input: string, replaceWhitespaceWith: string?): string
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConvertToUppercase = require(ReplicatedStorage.util.String.ConvertToUppercase)

local constantName: string = ConvertToUppercase("max ąę level", "_")
```

### `FormatNumberWithCommas`

Adds a comma every three digits in the integer part of a number. It works on `tostring(number)` and handles a leading `-` sign and a decimal part, which is kept unchanged. The function has no type annotations, so it also accepts numeric strings.

```luau
function FormatNumberWithCommas(number: number | string): string
```

Notes:

- The result depends on `tostring`. Very large or very small numbers turn into scientific notation (for example `1e+21`) and get formatted incorrectly. Floating point values can show long decimals (for example `0.30000000000000004`), so round them first.
- The source has comments written in Polish.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FormatNumberWithCommas = require(ReplicatedStorage.util.String.FormatNumberWithCommas)

local coinsText: string = FormatNumberWithCommas(1234567)
```

### `ReplaceStringTags`

Replaces the tags `@userId`, `@username` and `@displayname` in `text` with the `Players.LocalPlayer` user id, name and display name. The match is case-sensitive.

```luau
function ReplaceStringTags(text: string): string
```

Notes:

- It reads `Players.LocalPlayer`, so it only works on the client. On the server it throws an error.
- The tags are plain substring matches, so `@usernameXYZ` becomes `<name>XYZ`.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplaceStringTags = require(ReplicatedStorage.util.String.ReplaceStringTags)

local greeting: string = ReplaceStringTags("Welcome back, @displayname!")
```
