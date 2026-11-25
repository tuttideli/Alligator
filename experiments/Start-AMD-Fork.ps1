# Alligator experimental AMD renderer test.
# It builds a separate checkout and uses separate cache/data directories.
# The known DexNom Ultra v0.6 runtime is not modified.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,

    [switch]$EnableHairExperiment
)

$ErrorActionPreference = 'Stop'
$repoUrl = 'https://github.com/Belobug/VIctory-Belobug-AMD.git'
$reviewedCommit = '4f62c2a5e27e7beebf3e8d68f77898e43dc7b77c'
$engineRoot = Join-Path $env:LOCALAPPDATA 'Alligator\engines\VIctory-Belobug-AMD'
$dataRoot = Join-Path $env:LOCALAPPDATA 'Alligator\data\VIctory-Belobug-AMD'
$cacheDir = Join-Path $dataRoot 'cache'
$dataDir = Join-Path $dataRoot 'data'

function Invoke-Git([string[]]$GitArgs) {
    & git @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Git failed ($LASTEXITCODE): git $($GitArgs -join ' ')"
    }
}

if ($env:OS -ne 'Windows_NT' -or ![Environment]::Is64BitOperatingSystem) {
    throw 'This experiment requires 64-bit Windows.'
}
if (!(Test-Path -LiteralPath $GamePath -PathType Leaf)) {
    throw "Game executable not found: $GamePath"
}
$GamePath = (Get-Item -LiteralPath $GamePath).FullName
if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git for Windows is required.'
}
if (!(Get-Command cargo -ErrorAction SilentlyContinue)) {
    throw 'Rust Cargo is required. The fork pins Rust 1.98.1 in rust-toolchain.toml.'
}

New-Item -ItemType Directory -Path (Split-Path -Parent $engineRoot) -Force | Out-Null

if (!(Test-Path -LiteralPath (Join-Path $engineRoot '.git') -PathType Container)) {
    if (Test-Path -LiteralPath $engineRoot) {
        throw "The experiment folder exists but is not a Git checkout: $engineRoot"
    }
    Write-Host 'Downloading the AMD-oriented VIctory source in an isolated folder...' -ForegroundColor Cyan
    Invoke-Git @('clone', '--no-checkout', $repoUrl, $engineRoot)
} else {
    $origin = (& git -C $engineRoot remote get-url origin 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $origin -ne $repoUrl) {
        throw "Unexpected Git origin in $engineRoot. Refusing to alter this folder."
    }
    $changes = @(& git -C $engineRoot status --porcelain)
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the experiment checkout.' }
    if ($changes.Count -gt 0) {
        throw 'The experiment source has local changes. Commit or back them up before continuing.'
    }
    Invoke-Git @('-C', $engineRoot, 'fetch', '--no-tags', 'origin', $reviewedCommit)
}

Invoke-Git @('-C', $engineRoot, 'checkout', '--detach', $reviewedCommit)

$required = @(
    'Cargo.toml',
    'Cargo.lock',
    'rust-toolchain.toml',
    'apps\victory\Cargo.toml',
    'apps\victory\src\main.rs',
    'crates\victory-formats\src\bcpack-tables.bin'
)
foreach ($relative in $required) {
    $path = Join-Path $engineRoot $relative
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required source file is missing: $path"
    }
}

New-Item -ItemType Directory -Path $cacheDir, $dataDir -Force | Out-Null

Write-Host 'Compiling the AMD fork using its documented diagnostics build...' -ForegroundColor Cyan
Push-Location -LiteralPath $engineRoot
try {
    & cargo build --profile diag -p victory --features diagnostics
    if ($LASTEXITCODE -ne 0) {
        throw "Cargo build failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}

$runtimeExe = Join-Path $engineRoot 'target\diag\victory.exe'
if (!(Test-Path -LiteralPath $runtimeExe -PathType Leaf)) {
    throw "Build completed but the expected runtime was not found: $runtimeExe"
}

$processVariables = @('VICTORY_CACHE_DIR', 'VICTORY_DATA_DIR', 'VICTORY_HAIR')
$previous = @{}
foreach ($name in $processVariables) {
    $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

try {
    [Environment]::SetEnvironmentVariable('VICTORY_CACHE_DIR', $cacheDir, 'Process')
    [Environment]::SetEnvironmentVariable('VICTORY_DATA_DIR', $dataDir, 'Process')

    if ($EnableHairExperiment) {
        [Environment]::SetEnvironmentVariable('VICTORY_HAIR', '1', 'Process')
        Write-Warning 'Hair shader execution is experimental in this fork; compare it separately.'
    } else {
        [Environment]::SetEnvironmentVariable('VICTORY_HAIR', $null, 'Process')
    }

    Write-Host "AMD test build: $reviewedCommit" -ForegroundColor Gray
    Write-Host "Engine: $engineRoot" -ForegroundColor Gray
    Write-Host "Cache:  $cacheDir" -ForegroundColor Gray
    Write-Host "Data:   $dataDir" -ForegroundColor Gray
    Write-Host 'The first world load may take minutes while shaders and pipelines are translated/created.' -ForegroundColor Yellow
    Write-Host 'The fork uses a sky-following ambient-light approximation by default. It is not full ray-traced global illumination.' -ForegroundColor Yellow

    & $runtimeExe run $GamePath --execute --console series-x
    if ($LASTEXITCODE -ne 0) {
        throw "AMD fork exited with code $LASTEXITCODE."
    }
} finally {
    foreach ($name in $processVariables) {
        [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
    }
}
