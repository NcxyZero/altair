[CmdletBinding()]
param(
	[Alias("l")]
	[switch]$List,

	[Alias("f")]
	[switch]$Force,

	[Alias("h")]
	[switch]$Help,

	[Parameter(Position = 0, ValueFromRemainingArguments = $true)]
	[string[]]$Dependencies = @()
)

$ErrorActionPreference = "Stop"

$ProjectRoot = $PSScriptRoot
$ConfigFile = Join-Path $ProjectRoot "altair-dependencies.toml"
$ManifestName = "dependency.toml"

$DefaultRepositoryName = "altair-utils"
$DefaultRepositoryUrl = "https://github.com/NcxyZero/altair-utils"

$script:InstallPath = "src/util"
$script:Repositories = New-Object System.Collections.ArrayList
$script:WorkDir = $null

function Show-Usage {
	Write-Host @"
Usage: .\require-dependency.ps1 [options] <dependency> [dependency...]

Installs dependencies (for example Math, Camera, Audio) from the repositories
listed in altair-dependencies.toml into the configured install path.

When a dependency exists in more than one repository, you choose which ones to
install from by typing their numbers, for example "1 2 3", "1 2" or "2".

Options:
  -List, -l, --list     List dependencies available in every configured repository
  -Force, -f, --force   Reinstall already installed dependencies without asking
  -Help, -h, --help     Show this help

Examples:
  .\require-dependency.ps1 Math
  .\require-dependency.ps1 Math Camera Audio
  .\require-dependency.ps1 -List
"@
}

function Write-Warn([string]$Message) {
	Write-Host "Warning: $Message" -ForegroundColor Yellow
}

function Write-Fail([string]$Message) {
	Write-Host "Error: $Message" -ForegroundColor Red
}

function ConvertFrom-TomlString([string]$Raw) {
	$value = $Raw.Trim()

	if ($value.StartsWith('"')) {
		$value = $value.Substring(1)
		$end = $value.IndexOf('"')

		if ($end -ge 0) {
			return $value.Substring(0, $end)
		}

		return $value
	}

	if ($value.StartsWith("'")) {
		$value = $value.Substring(1)
		$end = $value.IndexOf("'")

		if ($end -ge 0) {
			return $value.Substring(0, $end)
		}

		return $value
	}

	$comment = $value.IndexOf("#")
	if ($comment -ge 0) {
		$value = $value.Substring(0, $comment)
	}

	return $value.Trim()
}

function ConvertFrom-TomlArray([string]$Raw) {
	$items = New-Object System.Collections.ArrayList

	if (-not $Raw) {
		return @()
	}

	$value = $Raw.Trim().TrimStart("[")
	$end = $value.IndexOf("]")
	if ($end -ge 0) {
		$value = $value.Substring(0, $end)
	}

	foreach ($part in $value.Split(",")) {
		$item = ConvertFrom-TomlString $part
		if ($item) {
			[void]$items.Add($item)
		}
	}

	return $items.ToArray()
}

function Read-TomlKey([string]$File, [string]$Key) {
	if (-not (Test-Path -LiteralPath $File -PathType Leaf)) {
		return $null
	}

	foreach ($rawLine in Get-Content -LiteralPath $File) {
		$line = $rawLine.Trim()

		if ($line.StartsWith("[")) {
			return $null
		}

		$separator = $line.IndexOf("=")
		if ($separator -gt 0 -and $line.Substring(0, $separator).Trim() -eq $Key) {
			return $line.Substring($separator + 1).Trim()
		}
	}

	return $null
}

function Add-Repository([string]$Name, [string]$Url, [string]$Branch, [string]$Path) {
	$repository = [PSCustomObject]@{
		Name = $Name
		Url = $Url
		Branch = $Branch
		Path = $Path
		Root = $null
	}

	[void]$script:Repositories.Add($repository)

	return $repository
}

function Import-Config {
	if (-not (Test-Path -LiteralPath $ConfigFile -PathType Leaf)) {
		Write-Warn "altair-dependencies.toml not found, using the default repository ($DefaultRepositoryName)."
		[void](Add-Repository $DefaultRepositoryName $DefaultRepositoryUrl "" "")

		return
	}

	$section = ""
	$current = $null
	$lineNumber = 0

	foreach ($rawLine in Get-Content -LiteralPath $ConfigFile) {
		$lineNumber++
		$line = $rawLine.Trim()

		if (-not $line -or $line.StartsWith("#")) {
			continue
		}

		if ($line -eq "[[repository]]") {
			$section = "repository"
			$current = Add-Repository "" "" "" ""

			continue
		}

		if ($line.StartsWith("[")) {
			$section = "unknown"

			continue
		}

		$separator = $line.IndexOf("=")
		if ($separator -le 0) {
			Write-Fail "altair-dependencies.toml:${lineNumber}: expected 'key = value'."

			exit 1
		}

		$key = $line.Substring(0, $separator).Trim()
		$value = ConvertFrom-TomlString $line.Substring($separator + 1)

		switch ("${section}:$key") {
			":install-path" { $script:InstallPath = $value }
			"repository:name" { $current.Name = $value }
			"repository:url" { $current.Url = $value }
			"repository:branch" { $current.Branch = $value }
			"repository:path" { $current.Path = $value }
			default { Write-Warn "altair-dependencies.toml:${lineNumber}: unknown key '$key' ignored." }
		}
	}

	if ($script:Repositories.Count -eq 0) {
		Write-Fail "altair-dependencies.toml does not list any [[repository]]."

		exit 1
	}

	$number = 0
	foreach ($repository in $script:Repositories) {
		$number++

		if (-not $repository.Url) {
			Write-Fail "altair-dependencies.toml: repository #$number has no url."

			exit 1
		}

		if (-not $repository.Name) {
			$url = $repository.Url.TrimEnd("/")
			if ($url.EndsWith(".git")) {
				$url = $url.Substring(0, $url.Length - 4)
			}

			$repository.Name = ($url -split "[/\\]")[-1]
		}
	}
}

function Get-RepositoryFiles {
	$script:WorkDir = Join-Path ([System.IO.Path]::GetTempPath()) ("altair-dependencies-" + [guid]::NewGuid().ToString("N"))
	[void](New-Item -ItemType Directory -Path $script:WorkDir)

	$index = 0
	foreach ($repository in $script:Repositories) {
		$destination = Join-Path $script:WorkDir $index
		$index++

		$arguments = @("clone", "--quiet", "--depth", "1")
		if ($repository.Branch) {
			$arguments += @("--branch", $repository.Branch)
		}

		$arguments += @($repository.Url, $destination)

		Write-Host "Fetching $($repository.Name) ($($repository.Url))..."

		$previousPreference = $ErrorActionPreference
		$ErrorActionPreference = "Continue"
		& git @arguments *> $null
		$exitCode = $LASTEXITCODE
		$ErrorActionPreference = $previousPreference

		if ($exitCode -ne 0) {
			Write-Warn "Could not fetch $($repository.Name), skipping it."

			continue
		}

		$root = $destination
		if ($repository.Path) {
			$root = Join-Path $destination $repository.Path
		}

		if (Test-Path -LiteralPath $root -PathType Container) {
			$repository.Root = $root
		} else {
			Write-Warn "Path '$($repository.Path)' does not exist in $($repository.Name), skipping it."
		}
	}
}

function Test-DependencyDirectory([System.IO.DirectoryInfo]$Directory) {
	if ($Directory.Name.StartsWith(".")) {
		return $false
	}

	if (Test-Path -LiteralPath (Join-Path $Directory.FullName $ManifestName) -PathType Leaf) {
		return $true
	}

	$luauFile = Get-ChildItem -LiteralPath $Directory.FullName -Recurse -File -Filter "*.luau" -ErrorAction SilentlyContinue | Select-Object -First 1

	return $null -ne $luauFile
}

function Get-DependencyDirectories([string]$Root) {
	if (-not $Root) {
		return @()
	}

	return @(Get-ChildItem -LiteralPath $Root -Directory | Where-Object { Test-DependencyDirectory $_ } | Sort-Object Name)
}

function Find-Dependency([string]$Root, [string]$Name) {
	foreach ($directory in @(Get-DependencyDirectories $Root)) {
		if ($directory.Name -ieq $Name) {
			return $directory
		}
	}

	return $null
}

function Show-Dependencies {
	$number = 0
	foreach ($repository in $script:Repositories) {
		$number++

		Write-Host ""
		Write-Host "[$number] $($repository.Name) ($($repository.Url))"

		if (-not $repository.Root) {
			Write-Host "  unavailable"

			continue
		}

		$directories = @(Get-DependencyDirectories $repository.Root)
		if ($directories.Count -eq 0) {
			Write-Host "  no dependencies found"

			continue
		}

		foreach ($directory in $directories) {
			$description = ConvertFrom-TomlString ([string](Read-TomlKey (Join-Path $directory.FullName $ManifestName) "description"))

			$status = ""
			if (Test-Path -LiteralPath (Join-Path (Join-Path $ProjectRoot $script:InstallPath) $directory.Name) -PathType Container) {
				$status = " (installed)"
			}

			if ($description) {
				Write-Host "  $($directory.Name)$status - $description"
			} else {
				Write-Host "  $($directory.Name)$status"
			}
		}
	}
}

function Read-Answer([string]$Prompt) {
	try {
		$answer = Read-Host $Prompt
	} catch {
		return $null
	}

	return $answer
}

function Confirm-Action([string]$Prompt) {
	$answer = Read-Answer "$Prompt [y/N]"
	if ($null -eq $answer) {
		return $false
	}

	$answer = $answer.Trim().ToLowerInvariant()

	return $answer -eq "y" -or $answer -eq "yes"
}

function Select-Repositories([string]$Name, [System.Collections.ArrayList]$Candidates) {
	$count = $Candidates.Count

	Write-Host ""
	Write-Host "`"$Name`" was found in $count/$($script:Repositories.Count) repositories:"

	for ($number = 1; $number -le $count; $number++) {
		$repository = $Candidates[$number - 1].Repository
		Write-Host "  $number) $($repository.Name) ($($repository.Url))"
	}

	while ($true) {
		$answer = Read-Answer 'Select repositories to install from (for example "1 2"), Enter for 1'
		if ($null -eq $answer) {
			Write-Warn "No input, installing from 1) only."
			$answer = "1"
		}

		$answer = $answer.Replace(",", " ").Trim()
		if (-not $answer) {
			$answer = "1"
		}

		$valid = $true
		$chosen = New-Object System.Collections.ArrayList

		foreach ($token in ($answer -split "\s+")) {
			$parsed = 0
			if (-not [int]::TryParse($token, [ref]$parsed) -or $parsed -lt 1 -or $parsed -gt $count) {
				$valid = $false

				break
			}

			if (-not $chosen.Contains($parsed)) {
				[void]$chosen.Add($parsed)
			}
		}

		if ($valid) {
			$selected = New-Object System.Collections.ArrayList
			foreach ($number in $chosen) {
				[void]$selected.Add($Candidates[$number - 1])
			}

			return ,$selected
		}

		Write-Host "Please type numbers between 1 and $count separated by spaces."
	}
}

function Copy-DependencyFiles([string]$Source, [string]$Target, [string]$RepositoryName) {
	$copied = 0
	$sourceRoot = (Resolve-Path -LiteralPath $Source).Path.TrimEnd("\", "/")

	foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -Recurse -File | Sort-Object FullName) {
		$relative = $file.FullName.Substring($sourceRoot.Length + 1)

		if ($relative -eq $ManifestName) {
			continue
		}

		$destination = Join-Path $Target $relative
		if (Test-Path -LiteralPath $destination) {
			Write-Warn "$($relative.Replace('\', '/')) from $RepositoryName skipped, a file with that name was already installed from another repository."

			continue
		}

		$parent = Split-Path -Parent $destination
		if (-not (Test-Path -LiteralPath $parent)) {
			[void](New-Item -ItemType Directory -Path $parent -Force)
		}

		Copy-Item -LiteralPath $file.FullName -Destination $destination
		$copied++
	}

	Write-Host "  + $copied file(s) from $RepositoryName"
}

function Test-Packages([string]$Name, [string]$Manifest) {
	$wallyFile = Join-Path $ProjectRoot "wally.toml"
	$wallyContent = ""
	if (Test-Path -LiteralPath $wallyFile -PathType Leaf) {
		$wallyContent = Get-Content -LiteralPath $wallyFile -Raw
	}

	foreach ($package in @(ConvertFrom-TomlArray ([string](Read-TomlKey $Manifest "packages")))) {
		$pattern = '(?m)^\s*"?' + [regex]::Escape($package) + '"?\s*='
		if (-not ($wallyContent -match $pattern)) {
			Write-Warn "$Name needs the Wally package '$package', which is not in wally.toml."
		}
	}
}

function Install-Dependency([string]$Requested, [bool]$Explicit, [System.Collections.ArrayList]$Queue, [System.Collections.ArrayList]$Installed, [System.Collections.ArrayList]$Failed) {
	$found = New-Object System.Collections.ArrayList

	foreach ($repository in $script:Repositories) {
		$directory = Find-Dependency $repository.Root $Requested
		if ($directory) {
			[void]$found.Add([PSCustomObject]@{ Repository = $repository; Directory = $directory })
		}
	}

	if ($found.Count -eq 0) {
		Write-Fail "Dependency `"$Requested`" was not found in any repository. Run with -List to see what is available."
		[void]$Failed.Add($Requested)

		return
	}

	$name = $found[0].Directory.Name
	$installRoot = Join-Path $ProjectRoot $script:InstallPath
	$target = Join-Path $installRoot $name

	if ($name -ieq "Core") {
		Write-Fail "Cannot install `"$name`": the Core folder is reserved for Altair's core utilities."
		[void]$Failed.Add($name)

		return
	}

	if (Test-Path -LiteralPath (Join-Path $installRoot "$name.luau") -PathType Leaf) {
		Write-Fail "Cannot install `"$name`": $($script:InstallPath)/$name.luau already exists and would clash with it."
		[void]$Failed.Add($name)

		return
	}

	if (Test-Path -LiteralPath $target -PathType Container) {
		if (-not $Explicit) {
			Write-Host "$name is already installed, skipping."

			return
		}

		if (-not $Force -and -not (Confirm-Action "$name is already installed in $($script:InstallPath)/$name. Reinstall it (the folder will be replaced)?")) {
			Write-Host "Skipped $name."

			return
		}
	}

	if ($found.Count -eq 1) {
		$selected = $found
	} else {
		$selected = Select-Repositories $name $found
	}

	if (Test-Path -LiteralPath $target) {
		Remove-Item -LiteralPath $target -Recurse -Force
	}

	[void](New-Item -ItemType Directory -Path $target -Force)

	Write-Host "Installing $name into $($script:InstallPath)/$name"

	foreach ($match in $selected) {
		$manifest = Join-Path $match.Directory.FullName $ManifestName

		Copy-DependencyFiles $match.Directory.FullName $target $match.Repository.Name
		Test-Packages $name $manifest

		foreach ($dependency in @(ConvertFrom-TomlArray ([string](Read-TomlKey $manifest "dependencies")))) {
			[void]$Queue.Add([PSCustomObject]@{ Name = $dependency; Explicit = $false })
		}
	}

	[void]$Installed.Add($name)
}

function Update-Sourcemap {
	if (-not (Get-Command rojo -ErrorAction SilentlyContinue)) {
		Write-Warn "rojo not found, run 'bash refresh-sourcemap.sh' after installing it."

		return
	}

	Push-Location $ProjectRoot
	try {
		$previousPreference = $ErrorActionPreference
		$ErrorActionPreference = "Continue"
		& rojo sourcemap default.project.json --output sourcemap.json *> $null
		$exitCode = $LASTEXITCODE
		$ErrorActionPreference = $previousPreference

		if ($exitCode -ne 0) {
			Write-Warn "Refreshing sourcemap.json failed."
		}
	} finally {
		Pop-Location
	}
}

function Invoke-Main {
	$requested = New-Object System.Collections.ArrayList

	foreach ($argument in $Dependencies) {
		switch -Regex ($argument) {
			"^(--list|-l)$" { $script:List = $true }
			"^(--force|-f)$" { $script:Force = $true }
			"^(--help|-h)$" { $script:Help = $true }
			"^-" {
				Write-Fail "Unknown option: $argument"
				Show-Usage

				exit 1
			}
			default { [void]$requested.Add($argument) }
		}
	}

	if ($Help) {
		Show-Usage

		exit 0
	}

	if (-not $List -and $requested.Count -eq 0) {
		Show-Usage

		exit 1
	}

	if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
		Write-Fail "git is required."

		exit 1
	}

	Import-Config
	Get-RepositoryFiles

	if ($List) {
		Show-Dependencies

		return 0
	}

	$queue = New-Object System.Collections.ArrayList
	$processed = New-Object System.Collections.ArrayList
	$installed = New-Object System.Collections.ArrayList
	$failed = New-Object System.Collections.ArrayList

	foreach ($name in $requested) {
		[void]$queue.Add([PSCustomObject]@{ Name = $name; Explicit = $true })
	}

	$position = 0
	while ($position -lt $queue.Count) {
		$entry = $queue[$position]
		$position++

		$key = $entry.Name.ToLowerInvariant()
		if ($processed.Contains($key)) {
			continue
		}

		[void]$processed.Add($key)
		Install-Dependency $entry.Name $entry.Explicit $queue $installed $failed
	}

	Write-Host ""

	if ($installed.Count -gt 0) {
		Update-Sourcemap
		Write-Host "Installed: $($installed -join ' ')"
		Write-Host "Installed into: $($script:InstallPath)/<Dependency>"
	} else {
		Write-Host "Nothing was installed."
	}

	if ($failed.Count -gt 0) {
		Write-Fail "Failed: $($failed -join ' ')"

		return 1
	}

	return 0
}

$exitCode = 1
try {
	$exitCode = Invoke-Main
} finally {
	if ($script:WorkDir -and (Test-Path -LiteralPath $script:WorkDir)) {
		Remove-Item -LiteralPath $script:WorkDir -Recurse -Force -ErrorAction SilentlyContinue
	}
}

exit $exitCode
