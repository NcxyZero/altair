param(
	[int]$DebounceMs = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-RefreshSourcemap {
	Write-Host ("[{0}] Regenerating sourcemap.json..." -f (Get-Date).ToString("HH:mm:ss"))
	& rojo sourcemap default.project.json --output sourcemap.json
	Write-Host ("[{0}] sourcemap.json updated." -f (Get-Date).ToString("HH:mm:ss"))
}

if (-not (Test-Path -LiteralPath "default.project.json")) {
	throw "default.project.json not found in repo root."
}

$srcWatcher = New-Object System.IO.FileSystemWatcher
$srcWatcher.Path = (Resolve-Path -LiteralPath "src").Path
$srcWatcher.Filter = "*"
$srcWatcher.IncludeSubdirectories = $true
$srcWatcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor `
	[System.IO.NotifyFilters]::DirectoryName
$srcWatcher.EnableRaisingEvents = $true

$rootWatcher = New-Object System.IO.FileSystemWatcher
$rootWatcher.Path = (Resolve-Path -LiteralPath ".").Path
$rootWatcher.Filter = "*.project.json"
$rootWatcher.IncludeSubdirectories = $false
$rootWatcher.NotifyFilter = [System.IO.NotifyFilters]::FileName
$rootWatcher.EnableRaisingEvents = $true

$subscriptions = @()
$subscriptions += Register-ObjectEvent -InputObject $srcWatcher -EventName Created -SourceIdentifier "sourcemapwatch.src.created"
$subscriptions += Register-ObjectEvent -InputObject $srcWatcher -EventName Deleted -SourceIdentifier "sourcemapwatch.src.deleted"
$subscriptions += Register-ObjectEvent -InputObject $srcWatcher -EventName Renamed -SourceIdentifier "sourcemapwatch.src.renamed"
$subscriptions += Register-ObjectEvent -InputObject $rootWatcher -EventName Created -SourceIdentifier "sourcemapwatch.root.created"
$subscriptions += Register-ObjectEvent -InputObject $rootWatcher -EventName Deleted -SourceIdentifier "sourcemapwatch.root.deleted"
$subscriptions += Register-ObjectEvent -InputObject $rootWatcher -EventName Renamed -SourceIdentifier "sourcemapwatch.root.renamed"

Write-Host "Watching for new files (src/** and *.project.json). Press Ctrl+C to stop."

$lastEventAt = $null
$lastEvent = $null

try {
	while ($true) {
		$receivedEvent = Wait-Event -Timeout 0.1
		if ($receivedEvent) {
			$lastEventAt = Get-Date
			$lastEvent = $receivedEvent
			Remove-Event -EventIdentifier $receivedEvent.EventIdentifier
			continue
		}

		if (-not $lastEventAt) {
			continue
		}

		$elapsedMs = (New-TimeSpan -Start $lastEventAt -End (Get-Date)).TotalMilliseconds
		if ($elapsedMs -lt $DebounceMs) {
			continue
		}

		$lastEventAt = $null

		if ($lastEvent) {
			$sourceEventArgs = $lastEvent.SourceEventArgs
			$changeType = $sourceEventArgs.ChangeType
			if ($changeType -ne "Created" -and $changeType -ne "Renamed") {
				continue
			}
			$fullPath = $sourceEventArgs.FullPath
			if ($changeType -eq "Renamed" -and $sourceEventArgs.OldFullPath) {
				Write-Host ("[{0}] Change detected: {1} {2} -> {3}" -f (Get-Date).ToString("HH:mm:ss"), $changeType, $sourceEventArgs.OldFullPath, $fullPath)
			}
			else {
				Write-Host ("[{0}] Change detected: {1} {2}" -f (Get-Date).ToString("HH:mm:ss"), $changeType, $fullPath)
			}
		}

		$lastEvent = $null
		Invoke-RefreshSourcemap
	}
}
finally {
	foreach ($sub in $subscriptions) {
		try { Unregister-Event -SourceIdentifier $sub.SourceIdentifier -ErrorAction SilentlyContinue } catch { }
	}
}
