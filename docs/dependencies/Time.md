# Time

Time helpers: format seconds as a clock string, build a UTC day id, get the seconds until the next UTC midnight, and run a delayed callback that can be cancelled.

## Installation

```bash
bash require-dependency.sh Time
```

```powershell
.\require-dependency.ps1 Time
```

Installed into `src/util/Time`, required as `ReplicatedStorage.util.Time.<Module>`.

## Requirements

- Wally packages: none
- Core utils: `IsValidUTF8` (used by `ConvertToDisplayTime`)
- Other packages: none

## Modules

### `ConvertToDisplayTime`

Formats `seconds` as zero-padded parts (`%02i`) joined by `customSeparator` (default `":"`). `displayType` is a string of unit letters. Order does not matter, and only `m`, `h` and `d` change the output. Seconds are always shown, and each unit you turn on adds a part in front: `"ms"` gives `MM:SS`, `"hms"` gives `HH:MM:SS`, `"dhms"` gives `DD:HH:MM:SS`. The largest unit you turn on is not wrapped, so `"ms"` with `3725` gives `62:05`.

```luau
function ConvertToDisplayTime(seconds: number, displayType: string, customSeparator: string?): string
```

Notes:

- It throws an error if `seconds` or `displayType` is missing, or if `displayType` is not valid UTF-8 (`IsValidUTF8` also prints a warning).
- Units depend on the smaller ones: `h` needs `m`, and `d` needs `h`. For example `"hs"` throws an error, because it does arithmetic on `nil` minutes.
- Without `m`, the seconds are not wrapped either (`ConvertToDisplayTime(125, "s")` returns `"125"`). Fractional seconds are cut off by `%02i`.
- The `format` helper is declared without `local`, so it also creates a global.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConvertToDisplayTime = require(ReplicatedStorage.util.Time.ConvertToDisplayTime)

local timerText: string = ConvertToDisplayTime(3725, "hms")
```

### `GetDayId`

Returns an id for the current UTC day in the form `"<dayOfYear>:<year>"`, for example `"306:2026"`. The day of year is not zero-padded. The id changes at UTC midnight, which makes it handy for daily rewards or daily resets.

```luau
function GetDayId(): string
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetDayId = require(ReplicatedStorage.util.Time.GetDayId)

local lastClaimDay: string = "305:2026"
local canClaim: boolean = lastClaimDay ~= GetDayId()
```

### `GetTimeUntilMidnight`

Returns the number of whole seconds until the next UTC midnight. It takes the current UTC time, sets the hour, minute and second to `0`, and adds 24 hours. At exactly midnight it returns `86400`.

```luau
function GetTimeUntilMidnight(): number
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConvertToDisplayTime = require(ReplicatedStorage.util.Time.ConvertToDisplayTime)
local GetTimeUntilMidnight = require(ReplicatedStorage.util.Time.GetTimeUntilMidnight)

local resetText: string = ConvertToDisplayTime(GetTimeUntilMidnight(), "hms")
```

### `SetTimeout`

Schedules `func` with `task.delay(time, ...)` and returns a function that cancels it. If `time` is `nil`, the callback runs on the next resumption cycle. Cancelling only sets a flag, so the delayed thread still wakes up but returns without calling `func`. Calling cancel after the callback has run does nothing. `func` runs in its own thread and gets no arguments.

```luau
function SetTimeout(time: number?, func: () -> ...any): () -> ()
```

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SetTimeout = require(ReplicatedStorage.util.Time.SetTimeout)

local cancel: () -> () = SetTimeout(5, function(): ()
  print("Round started")
end)

cancel()
```
