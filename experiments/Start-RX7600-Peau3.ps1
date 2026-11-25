[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,

    [string]$FidelityFxDir,

    [ValidateRange(1, 16)]
    [int]$BuildJobs = 4
)

$ErrorActionPreference = 'Stop'

$forkUrl = 'https://github.com/AntoninMichelq/VIctory-forkAMD.git'
$testedCommit = 'b74ac64da2e289cc632980cf8e508c2d1ba909ac'
$engineRoot = Join-Path $env:LOCALAPPDATA 'Alligator\engines\VIctory-RX7600-Peau3'
$dataRoot = Join-Path $env:LOCALAPPDATA 'Alligator\data\VIctory-RX7600-Peau3'
$cacheDir = Join-Path $dataRoot 'cache'
$userDataDir = Join-Path $dataRoot 'data'
$targetDir = Join-Path $env:LOCALAPPDATA 'Alligator\targets\VIctory-RX7600-Peau3'
$runDir = Join-Path $env:LOCALAPPDATA 'Alligator\runs\VIctory-RX7600-Peau3'
$runtimeExe = Join-Path $targetDir 'release\victory.exe'

function Invoke-Git([string[]]$GitArgs) {
    & git @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Git failed ($LASTEXITCODE): git $($GitArgs -join ' ')"
    }
}

function Assert-NoVictoryProcess {
    $running = @(Get-Process -Name 'victory','victory-play','victory-warm' -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        $names = ($running | Select-Object -ExpandProperty ProcessName -Unique) -join ', '
        throw "Another VIctory/DexNom process is running ($names). Close it normally before starting this isolated test. No process was terminated."
    }
}

if ($env:OS -ne 'Windows_NT' -or ![Environment]::Is64BitOperatingSystem) {
    throw 'The RX 7600 Peau3 test requires 64-bit Windows.'
}
if (!(Test-Path -LiteralPath $GamePath -PathType Leaf)) {
    throw "Game executable not found: $GamePath"
}
$GamePath = (Get-Item -LiteralPath $GamePath).FullName

if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git for Windows is required.'
}
if (!(Get-Command cargo -ErrorAction SilentlyContinue)) {
    throw 'Rust Cargo is required. The checkout pins Rust 1.98.1 in rust-toolchain.toml.'
}

Assert-NoVictoryProcess

# This exact RX 7600 result was measured with 32 GB RAM and used about 21 GB
# during a 10-minute run. Do not silently assume a 16 GB PC can reproduce it.
try {
    $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $ramGiB = [Math]::Round(([double]$computer.TotalPhysicalMemory / 1GB), 1)
    $gpuNames = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | Select-Object -ExpandProperty Name)
    $pagefiles = @(Get-CimInstance Win32_PageFileUsage -ErrorAction Stop)
    $pagefileGiB = 0.0
    foreach ($pagefile in $pagefiles) {
        $pagefileGiB += ([double]$pagefile.AllocatedBaseSize / 1024.0)
    }
} catch {
    throw "Could not read the hardware/memory preflight. No source was built and no game was launched. $($_.Exception.Message)"
}

Write-Host ''
Write-Host 'RX 7600 / PEAU3 HARDWARE PREFLIGHT' -ForegroundColor Cyan
Write-Host ("GPU: " + ($gpuNames -join '; '))
Write-Host ("Physical RAM: {0:N1} GiB" -f $ramGiB)
Write-Host ("Currently allocated page file: {0:N1} GiB" -f $pagefileGiB)

if (!(($gpuNames -join '; ') -match 'RX 7600')) {
    Write-Warning 'The documented test was on an AMD RX 7600 8 GB. Your detected GPU differs; results may not transfer.'
}
if ($ramGiB -lt 32) {
    Write-Warning 'The matching RX 7600 test used 32 GiB physical RAM and held about 21 GiB during a 10-minute run. With less RAM, Windows may page heavily and the game may stutter or fail.'
    if ($pagefileGiB -lt 20) {
        throw 'Low-memory safety stop: less than 32 GiB physical RAM and less than 20 GiB currently allocated page file. Increase/verify the Windows page file and rerun. Alligator will not change paging or registry settings.'
    }
    $answer = Read-Host 'To continue despite the lower physical RAM and possible paging, type LOW-RAM-TEST'
    if ($answer -cne 'LOW-RAM-TEST') {
        Write-Host 'Test cancelled. No source was built and no game was launched.' -ForegroundColor Yellow
        return
    }
}

# This tested profile uses the PC FidelityFX SDK DLL to render internally at
# 1080p and upscale to the title's fixed 4K output. Require it rather than
# quietly launching a different, unbenchmarked 4K configuration.
if ([string]::IsNullOrWhiteSpace($FidelityFxDir)) {
    $FidelityFxDir = [Environment]::GetEnvironmentVariable('VICTORY_FIDELITYFX_DIR', 'Process')
}
if ([string]::IsNullOrWhiteSpace($FidelityFxDir)) {
    $guess = Join-Path $env:LOCALAPPDATA 'Alligator\FidelityFX\Kits\FidelityFX\signedbin'
    if (Test-Path -LiteralPath (Join-Path $guess 'amd_fidelityfx_upscaler_dx12.dll') -PathType Leaf) {
        $FidelityFxDir = $guess
    }
}
if ([string]::IsNullOrWhiteSpace($FidelityFxDir)) {
    $FidelityFxDir = Read-Host 'Enter the folder containing amd_fidelityfx_upscaler_dx12.dll (Enter to cancel)'
}
if ([string]::IsNullOrWhiteSpace($FidelityFxDir)) {
    throw 'The validated 1080p-to-4K FidelityFX path was not configured. Set fidelityFxDirectory in config\settings.json or pass -FidelityFxDir.'
}
$FidelityFxDir = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($FidelityFxDir.Trim()))
$fxDll = Join-Path $FidelityFxDir 'amd_fidelityfx_upscaler_dx12.dll'
if (!(Test-Path -LiteralPath $fxDll -PathType Leaf)) {
    throw "PC FidelityFX DLL not found: $fxDll. Point FidelityFxDir at the SDK folder that contains amd_fidelityfx_upscaler_dx12.dll."
}

New-Item -ItemType Directory -Path (Split-Path -Parent $engineRoot), $dataRoot, $targetDir, $runDir -Force | Out-Null

if (!(Test-Path -LiteralPath (Join-Path $engineRoot '.git') -PathType Container)) {
    if (Test-Path -LiteralPath $engineRoot) {
        throw "The engine folder exists but is not a Git checkout: $engineRoot. It was not modified."
    }
    Write-Host 'Cloning the RX 7600-tested VIctory fork into an isolated folder...' -ForegroundColor Cyan
    Invoke-Git @('clone', '--no-checkout', $forkUrl, $engineRoot)
} else {
    $origin = (& git -C $engineRoot remote get-url origin 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $origin -notin @($forkUrl, 'https://github.com/AntoninMichelq/VIctory-forkAMD')) {
        throw "Unexpected Git origin in $engineRoot ($origin). Refusing to alter this folder."
    }
    $changes = @(& git -C $engineRoot status --porcelain)
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the RX 7600 fork checkout.' }
    if ($changes.Count -gt 0) {
        throw 'Local changes exist in the RX 7600 fork checkout. Commit or back them up before continuing.'
    }
    Invoke-Git @('-C', $engineRoot, 'fetch', '--no-tags', 'origin', 'jouer/peau3')
}

Invoke-Git @('-C', $engineRoot, 'checkout', '--detach', $testedCommit)

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
        throw "Required source/build file is missing: $path"
    }
}

Write-Host ''
Write-Host 'Pinned source: AntoninMichelq/VIctory-forkAMD' -ForegroundColor Gray
Write-Host "Reviewed commit: $testedCommit" -ForegroundColor Gray
Write-Host 'This is the Peau3 configuration measured on an RX 7600 8 GB. The report says about 6.2-6.5 FPS in the tested prison scene with 32 GB RAM; it is not a 30 FPS or full-playability guarantee.' -ForegroundColor Yellow
Write-Host 'The current DexNom v0.6 runtime, game files and shader cache are not replaced.' -ForegroundColor Green

$previousTarget = [Environment]::GetEnvironmentVariable('CARGO_TARGET_DIR', 'Process')
try {
    [Environment]::SetEnvironmentVariable('CARGO_TARGET_DIR', $targetDir, 'Process')
    Write-Host ''
    Write-Host "Building release binary with $BuildJobs Cargo jobs..." -ForegroundColor Cyan
    Push-Location -LiteralPath $engineRoot
    try {
        & cargo build --release -p victory --jobs $BuildJobs
        if ($LASTEXITCODE -ne 0) {
            throw "Cargo release build failed with exit code $LASTEXITCODE."
        }
    } finally {
        Pop-Location
    }
} finally {
    [Environment]::SetEnvironmentVariable('CARGO_TARGET_DIR', $previousTarget, 'Process')
}

if (!(Test-Path -LiteralPath $runtimeExe -PathType Leaf)) {
    throw "Build completed but the expected executable was not found: $runtimeExe"
}

Write-Host ''
Write-Host 'TESTED RX 7600 PROFILE' -ForegroundColor Cyan
Write-Host 'Internal render: 1080p | output: 4K via PC FidelityFX | texture mip reduction: 2'
Write-Host 'Ambient replacement: off | wave64 path: on | shader optimizer: off'
Write-Host "FidelityFX: $FidelityFxDir"
Write-Host 'The first run may spend extra time preparing shaders and pipelines.' -ForegroundColor Yellow

$answer = Read-Host 'After reviewing the memory warning above, type TEST to launch this separate renderer; anything else cancels'
if ($answer -cne 'TEST') {
    Write-Host 'Build kept for later. No game was launched.' -ForegroundColor Yellow
    return
}

Assert-NoVictoryProcess

New-Item -ItemType Directory -Path $cacheDir, $userDataDir -Force | Out-Null

$variables = @{
    'DISABLE_VULKAN_OBS_CAPTURE' = '1'
    'VICTORY_LOG' = 'info'
    'VICTORY_CACHE_DIR' = $cacheDir
    'VICTORY_DATA_DIR' = $userDataDir
    'VICTORY_LATE_WAIT' = '3'
    'VICTORY_WIDE_BACK' = '1'
    'VICTORY_WIDE_MERGE' = '1'
    'VICTORY_JOIN_COPIES' = '1'
    'VICTORY_WIDE_REFRESH' = '1'
    'VICTORY_RELAY' = '2'
    'VICTORY_TEXTURE_NO_WAIT' = '1'
    'VICTORY_CARD_BUFFERS_MIN_MB' = '1'
    'VICTORY_CARD_BUFFERS_MB' = '512'
    'VICTORY_STAGING_POOL_MB' = '1024'
    'VICTORY_VRAM_HYSTERESIS' = '85,75'
    'VICTORY_AMBIENT' = 'off'
    'VICTORY_TEXTURE_HALF' = '2'
    'VICTORY_WAVE_WIDE' = '1'
    'VICTORY_SHADER_OPT' = '0'
    'VICTORY_FIDELITYFX_DIR' = $FidelityFxDir
    'VICTORY_UPSCALER' = '7E93F0'
    'VICTORY_FFX_SCALE' = '0.5'
    'VICTORY_WIDE_TEXTURES' = '1'
    'VICTORY_CARD_GATHER' = '1'
    'VICTORY_NO_COMPILE' = 'none'
}

$previous = @{}
foreach ($name in $variables.Keys) {
    $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    [Environment]::SetEnvironmentVariable($name, [string]$variables[$name], 'Process')
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $runDir "run-$stamp-peau3.log"

try {
    Write-Host ''
    Write-Host 'Launching isolated RX 7600 Peau3 runtime...' -ForegroundColor Green
    Write-Host "Game: $GamePath" -ForegroundColor Gray
    Write-Host "Cache: $cacheDir" -ForegroundColor Gray
    Write-Host "Data: $userDataDir" -ForegroundColor Gray
    Write-Host "Log: $logPath" -ForegroundColor Gray
    & $runtimeExe run $GamePath --execute --console series-x 2>&1 | Tee-Object -FilePath $logPath
    $runExitCode = $LASTEXITCODE
    if ($runExitCode -ne 0) {
        throw "RX 7600 Peau3 runtime exited with code $runExitCode. Review $logPath"
    }
} finally {
    foreach ($name in $variables.Keys) {
        [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
    }
}

Write-Host ''
Write-Host "RX 7600 Peau3 run finished. Log: $logPath" -ForegroundColor Green
