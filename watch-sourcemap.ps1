param(
	[Parameter(Position = 0)]
	[string]$Project = "default.project.json",
	[int]$DebounceMs = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Set-Location -LiteralPath $PSScriptRoot

$projectFile = $Project
if (-not $projectFile.EndsWith(".project.json", [System.StringComparison]::OrdinalIgnoreCase)) {
	$projectFile += ".project.json"
}
if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
	throw "Project file not found: $projectFile"
}

function Invoke-RefreshSourcemap {
	Write-Host ("[{0}] Regenerating sourcemap.json..." -f (Get-Date).ToString("HH:mm:ss"))
	& rojo sourcemap $projectFile --output sourcemap.json
	if ($LASTEXITCODE -ne 0) {
		throw "Rojo sourcemap failed for $projectFile with exit code $LASTEXITCODE."
	}

	Write-Host ("[{0}] sourcemap.json updated." -f (Get-Date).ToString("HH:mm:ss"))
}

function Remove-SourcemapWatchEvents {
	Get-EventSubscriber -ErrorAction SilentlyContinue |
		Where-Object { $_.SourceIdentifier -like "sourcemapwatch.*" } |
		Unregister-Event -ErrorAction SilentlyContinue
	Get-Event -ErrorAction SilentlyContinue |
		Where-Object { $_.SourceIdentifier -like "sourcemapwatch.*" } |
		Remove-Event -ErrorAction SilentlyContinue
}

Invoke-RefreshSourcemap

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
$rootWatcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor `
	[System.IO.NotifyFilters]::LastWrite
$rootWatcher.EnableRaisingEvents = $true

# Register-ObjectEvent without -Action returns nothing, so cleanup filters subscriptions by source identifier.
Remove-SourcemapWatchEvents
Register-ObjectEvent -InputObject $srcWatcher -EventName Created -SourceIdentifier "sourcemapwatch.src.created"
Register-ObjectEvent -InputObject $srcWatcher -EventName Deleted -SourceIdentifier "sourcemapwatch.src.deleted"
Register-ObjectEvent -InputObject $srcWatcher -EventName Renamed -SourceIdentifier "sourcemapwatch.src.renamed"
Register-ObjectEvent -InputObject $rootWatcher -EventName Created -SourceIdentifier "sourcemapwatch.root.created"
Register-ObjectEvent -InputObject $rootWatcher -EventName Deleted -SourceIdentifier "sourcemapwatch.root.deleted"
Register-ObjectEvent -InputObject $rootWatcher -EventName Renamed -SourceIdentifier "sourcemapwatch.root.renamed"
Register-ObjectEvent -InputObject $rootWatcher -EventName Changed -SourceIdentifier "sourcemapwatch.root.changed"

Write-Host "Watching src/** and *.project.json for $projectFile. Press Ctrl+C to stop."

$lastEventAt = $null
$lastEvent = $null

try {
	while ($true) {
		$receivedEvent = Get-Event -ErrorAction SilentlyContinue |
			Where-Object { $_.SourceIdentifier -like "sourcemapwatch.*" } |
			Select-Object -First 1
		if ($receivedEvent) {
			$lastEventAt = Get-Date
			$lastEvent = $receivedEvent
			Remove-Event -EventIdentifier $receivedEvent.EventIdentifier
			continue
		}

		Start-Sleep -Milliseconds 100

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
			$fullPath = $sourceEventArgs.FullPath
			if ($changeType -eq "Renamed" -and $sourceEventArgs.OldFullPath) {
				Write-Host ("[{0}] Change detected: {1} {2} -> {3}" -f (Get-Date).ToString("HH:mm:ss"), $changeType, $sourceEventArgs.OldFullPath, $fullPath)
			}
			else {
				Write-Host ("[{0}] Change detected: {1} {2}" -f (Get-Date).ToString("HH:mm:ss"), $changeType, $fullPath)
			}
		}

		$lastEvent = $null

		# A failed refresh (for example a half-saved project file) must not stop the watcher.
		try {
			Invoke-RefreshSourcemap
		}
		catch {
			Write-Warning ("[{0}] {1} Still watching for changes." -f (Get-Date).ToString("HH:mm:ss"), $_.Exception.Message)
		}
	}
}
finally {
	Remove-SourcemapWatchEvents

	$srcWatcher.Dispose()
	$rootWatcher.Dispose()
}
