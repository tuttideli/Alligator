# Alligator self-updater.
# Updates this repository only. It never updates or replaces DexNom engine files.
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'
$git = Get-Command git -ErrorAction SilentlyContinue
if (!$git) { throw 'Git is required. Install Git for Windows before updating Alligator.' }

$root = [IO.Path]::GetFullPath($RepositoryRoot)
if (!(Test-Path -LiteralPath (Join-Path $root '.git'))) {
    throw "Not a Git checkout: $root. Clone https://github.com/tuttideli/Alligator.git first."
}

$top = (& git -C $root rev-parse --show-toplevel 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($top) -ine $root) {
    throw "Git root does not match the supplied repository folder: $root"
}

$remote = (& git -C $root remote get-url origin 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Git remote origin is missing.' }
$allowed = @(
    'https://github.com/tuttideli/Alligator.git',
    'https://github.com/tuttideli/Alligator',
    'git@github.com:tuttideli/Alligator.git'
)
if ($remote -notin $allowed) {
    throw "Unexpected origin '$remote'. This updater is restricted to tuttideli/Alligator."
}

$currentBranch = (& git -C $root branch --show-current 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Could not read the current Git branch.' }
if ($currentBranch -ne $Branch) {
    throw "Current branch is '$currentBranch', expected '$Branch'. Switch to $Branch before updating."
}

$changes = @(& git -C $root status --porcelain)
if ($LASTEXITCODE -ne 0) { throw 'Could not check the working tree.' }
if ($changes.Count -gt 0) {
    throw 'Local Alligator changes detected. Commit or back them up before updating; no files were changed.'
}

Write-Host "Checking $remote ($Branch)..." -ForegroundColor Cyan
& git -C $root fetch --prune origin
if ($LASTEXITCODE -ne 0) { throw 'Git fetch failed. No local files were changed.' }

$countText = (& git -C $root rev-list --left-right --count "HEAD...origin/$Branch" 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw "Could not compare local and remote commits: $countText" }
$counts = $countText -split '\s+'
if ($counts.Count -ne 2) { throw "Unexpected Git comparison result: $countText" }
$ahead = [int]$counts[0]
$behind = [int]$counts[1]

if ($behind -eq 0 -and $ahead -eq 0) {
    Write-Host 'Alligator is already up to date.' -ForegroundColor Green
    return
}
if ($ahead -gt 0) {
    throw "Local branch is ahead by $ahead commit(s); refusing to overwrite or rewrite history."
}
if ($behind -gt 0) {
    & git -C $root merge --ff-only "origin/$Branch"
    if ($LASTEXITCODE -ne 0) { throw 'Fast-forward update failed. No forced reset was attempted.' }
    Write-Host "Alligator updated by $behind commit(s)." -ForegroundColor Green
}
