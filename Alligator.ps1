# Alligator - main control script for DexNom Ultra
# Windows PowerShell 5.1 compatible. Does not modify game files or caches.
[CmdletBinding()]
param(
    [ValidateSet('Launch','Build','Doctor','Profiles','Rollback','Report','Update')]
    [string]$Action = 'Launch',
    [string]$Profile,
    [string]$GamePath,
    [string]$SourceRoot,
    [switch]$Warmup,
    [switch]$RawLog
)

$ErrorActionPreference = 'Stop'
$script:RepoRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$script:ConfigDir = Join-Path $script:RepoRoot 'config'
$script:ConfigPath = Join-Path $script:ConfigDir 'settings.json'
$script:ExampleConfigPath = Join-Path $script:ConfigDir 'settings.example.json'
$script:RuntimeDefault = Join-Path $env:LOCALAPPDATA 'DexNom Ultra Performance v0.1'

function Write-Section([string]$Title) {
    Write-Host ''
    Write-Host ('=' * 66) -ForegroundColor DarkCyan
    Write-Host (' ALLIGATOR | ' + $Title) -ForegroundColor Cyan
    Write-Host ('=' * 66) -ForegroundColor DarkCyan
}

function Resolve-UserPath([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $expanded = [Environment]::ExpandEnvironmentVariables($Value.Trim())
    return [IO.Path]::GetFullPath($expanded)
}

function Get-AlligatorConfig {
    if (!(Test-Path -LiteralPath $script:ConfigPath -PathType Leaf)) {
        if (!(Test-Path -LiteralPath $script:ExampleConfigPath -PathType Leaf)) {
            throw "Configuration template not found: $script:ExampleConfigPath"
        }
        Copy-Item -LiteralPath $script:ExampleConfigPath -Destination $script:ConfigPath
        Write-Host "Created local configuration: $script:ConfigPath" -ForegroundColor Gray
        Write-Host 'Edit config\settings.json to save your local game and source paths.' -ForegroundColor Gray
    }
    try {
        $value = Get-Content -LiteralPath $script:ConfigPath -Raw | ConvertFrom-Json
    } catch {
        throw "Invalid JSON in config\settings.json: $($_.Exception.Message)"
    }
    if ($null -eq $value) { throw 'The local settings file is empty.' }
    return $value
}

function Get-Setting($Config, [string]$Name, [string]$Fallback) {
    if ($Config.PSObject.Properties.Name -contains $Name) {
        $value = [string]$Config.$Name
        if (![string]::IsNullOrWhiteSpace($value)) { return $value }
    }
    return $Fallback
}

function Get-EngineSourceRoot($Config) {
    if ($PSBoundParameters.ContainsKey('SourceRoot') -and ![string]::IsNullOrWhiteSpace($SourceRoot)) {
        return Resolve-UserPath $SourceRoot
    }
    $configured = Get-Setting $Config 'engineSourceDirectory' '%USERPROFILE%\Downloads\DexNom-UltraPerformance-v0.1'
    return Resolve-UserPath $configured
}

function Get-RuntimeDirectory($Config) {
    $configured = Get-Setting $Config 'runtimeDirectory' $script:RuntimeDefault
    return Resolve-UserPath $configured
}

function Get-SelectedGamePath($Config, [string]$RuntimeDir) {
    if (![string]::IsNullOrWhiteSpace($GamePath)) {
        return Resolve-UserPath $GamePath
    }
    $configured = Get-Setting $Config 'gameExecutable' ''
    if (![string]::IsNullOrWhiteSpace($configured)) {
        return Resolve-UserPath $configured
    }
    $saved = Join-Path $RuntimeDir 'game-path.txt'
    if (Test-Path -LiteralPath $saved -PathType Leaf) {
        $value = [IO.File]::ReadAllText($saved).Trim()
        if ($value) { return Resolve-UserPath $value }
    }
    return $null
}

function Assert-EngineSource([string]$Root) {
    if (!(Test-Path -LiteralPath $Root -PathType Container)) {
        throw "DexNom Ultra source directory not found: $Root"
    }
    $required = @(
        'Cargo.toml',
        'Cargo.lock',
        'Initialize-FormatTables.ps1',
        'ultra\Build-Ultra.ps1',
        'ultra\Start-Ultra.ps1',
        'ultra\Live-Monitor.ps1',
        'ultra\Enviar-Ultimo-Jogo.ps1'
    )
    foreach ($relative in $required) {
        $path = Join-Path $Root $relative
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Required v0.6 file is missing: $path"
        }
    }
    $repoPrefix = $script:RepoRoot.TrimEnd('\') + '\'
    $sourcePrefix = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    if ($sourcePrefix.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Keep the DexNom engine source outside the public Alligator repository.'
    }
}

function Assert-RuntimeClosed {
    $running = @(Get-Process -Name 'victory','victory-play','victory-warm' -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        $names = ($running | Select-Object -ExpandProperty ProcessName -Unique) -join ', '
        throw "Close the game/runtime before building or rolling back. Running: $names"
    }
}

function Get-ProfileDescription {
    return @(
        [pscustomobject]@{ Profile='UltraSafe1080'; Purpose='Safer visual profile; disables the extra material-demand and long bake experiment.'; Risk='Default comparison profile' },
        [pscustomobject]@{ Profile='UltraPerf1080'; Purpose='Adds the v0.6 card rehash experiment to the Ultra 1080p path.'; Risk='Experimental; benchmark against UltraSafe1080' },
        [pscustomobject]@{ Profile='Visibility1080'; Purpose='Legacy visibility lift, lower gain than Ultra visual profiles.'; Risk='Experimental presentation correction' },
        [pscustomobject]@{ Profile='Display720'; Purpose='Reports 1280x720 as the title display mode.'; Risk='Does not guarantee a lower internal render resolution' },
        [pscustomobject]@{ Profile='Workers4'; Purpose='Four workers for eligible fill/upload work.'; Risk='May help only a narrow CPU path' },
        [pscustomobject]@{ Profile='Preludes'; Purpose='Parallel recording of eligible command-list preludes.'; Risk='Scene-dependent' },
        [pscustomobject]@{ Profile='Baseline'; Purpose='Patched renderer with default runtime settings.'; Risk='Reference profile' },
        [pscustomobject]@{ Profile='UltraVisual1080'; Purpose='Material-demand sampling plus early texture/bake work.'; Risk='Can increase loading and frame work; not preferred for FPS baseline' },
        [pscustomobject]@{ Profile='UltraVisualStrong1080'; Purpose='Visual profile with stronger presentation lift.'; Risk='Visual experiment; not an FPS profile' },
        [pscustomobject]@{ Profile='UltraLightingTrace1080'; Purpose='Enables extra lighting/accounting diagnostics.'; Risk='Diagnostic overhead; not for performance measurement' }
    )
}

try {
    $config = Get-AlligatorConfig
    $engineRoot = Get-EngineSourceRoot $config
    $runtimeDir = Get-RuntimeDirectory $config
    $selectedGame = Get-SelectedGamePath $config $runtimeDir
    $selectedProfile = if (![string]::IsNullOrWhiteSpace($Profile)) { $Profile } else { Get-Setting $config 'defaultProfile' 'UltraSafe1080' }

    switch ($Action) {
        'Profiles' {
            Write-Section 'AVAILABLE PROFILES'
            Get-ProfileDescription | Format-Table -Wrap -AutoSize
            Write-Host 'Use -Profile to choose a profile. The same save, camera, scene and cache state are needed for a useful comparison.' -ForegroundColor Gray
            break
        }
        'Doctor' {
            Write-Section 'SYSTEM AND FILE CHECK'
            $checks = New-Object 'System.Collections.Generic.List[object]'
            function Add-DoctorCheck([string]$Name, [bool]$Ok, [string]$Detail) {
                $status = if ($Ok) { 'OK' } else { 'CHECK' }
                $script:DoctorChecks.Add([pscustomobject]@{ Check=$Name; Status=$status; Detail=$Detail })
            }
            $script:DoctorChecks = $checks
            Add-DoctorCheck 'Windows x64' ([Environment]::Is64BitOperatingSystem -and $env:OS -eq 'Windows_NT') ([Environment]::OSVersion.VersionString)
            Add-DoctorCheck 'Git' ([bool](Get-Command git -ErrorAction SilentlyContinue)) 'Needed for Alligator self-update'
            Add-DoctorCheck 'Rust Cargo' ([bool](Get-Command cargo -ErrorAction SilentlyContinue)) 'Needed only when compiling the engine'
            Add-DoctorCheck 'DexNom source directory' (Test-Path -LiteralPath $engineRoot -PathType Container) $engineRoot
            foreach ($relative in 'ultra\Build-Ultra.ps1','ultra\Start-Ultra.ps1','ultra\Live-Monitor.ps1','ultra\Enviar-Ultimo-Jogo.ps1','Initialize-FormatTables.ps1') {
                $path = Join-Path $engineRoot $relative
                Add-DoctorCheck $relative (Test-Path -LiteralPath $path -PathType Leaf) $path
            }
            Add-DoctorCheck 'Runtime directory' (Test-Path -LiteralPath $runtimeDir -PathType Container) $runtimeDir
            foreach ($name in 'victory.exe','victory-play.exe','victory-warm.exe') {
                $path = Join-Path $runtimeDir $name
                Add-DoctorCheck $name (Test-Path -LiteralPath $path -PathType Leaf) $path
            }
            Add-DoctorCheck 'Game executable' ([bool]($selectedGame -and (Test-Path -LiteralPath $selectedGame -PathType Leaf))) $(if ($selectedGame) { $selectedGame } else { 'Not configured' })
            try {
                $gpuNames = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | Select-Object -ExpandProperty Name)
                Add-DoctorCheck 'GPU detection' ($gpuNames.Count -gt 0) ($gpuNames -join '; ')
            } catch {
                Add-DoctorCheck 'GPU detection' $false $_.Exception.Message
            }
            $checks | Format-Table -AutoSize -Wrap
            Write-Host 'Doctor checks file presence and prerequisites only; it does not certify performance or compatibility.' -ForegroundColor Gray
            break
        }
        'Build' {
            Write-Section 'BUILD DEXNOM ULTRA'
            Assert-EngineSource $engineRoot
            Assert-RuntimeClosed
            $buildScript = Join-Path $engineRoot 'ultra\Build-Ultra.ps1'
            if ($selectedGame) {
                if (!(Test-Path -LiteralPath $selectedGame -PathType Leaf)) { throw "Game executable not found: $selectedGame" }
                & $buildScript -GamePath $selectedGame
            } else {
                & $buildScript
            }
            if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "Build returned exit code $LASTEXITCODE." }
            Write-Host 'Build script completed. The original build script handles its own binary backup.' -ForegroundColor Green
            break
        }
        'Rollback' {
            Write-Section 'ROLL BACK RUNTIME BINARIES'
            Assert-EngineSource $engineRoot
            Assert-RuntimeClosed
            & (Join-Path $engineRoot 'ultra\Build-Ultra.ps1') -Rollback
            if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "Rollback returned exit code $LASTEXITCODE." }
            break
        }
        'Report' {
            Write-Section 'EXPORT LAST SESSION REPORT'
            Assert-EngineSource $engineRoot
            $reportScript = Join-Path $engineRoot 'ultra\Enviar-Ultimo-Jogo.ps1'
            & $reportScript -SourceRoot $engineRoot -RuntimeDir $runtimeDir -OutputDir (Join-Path $env:USERPROFILE 'Downloads') -NoQuestions
            break
        }
        'Update' {
            Write-Section 'UPDATE ALLIGATOR'
            & (Join-Path $script:RepoRoot 'updater\Update.ps1') -RepositoryRoot $script:RepoRoot
            break
        }
        'Launch' {
            Write-Section "LAUNCH DEXNOM ULTRA | $selectedProfile"
            Assert-EngineSource $engineRoot
            if (!(Test-Path -LiteralPath (Join-Path $runtimeDir 'victory-play.exe') -PathType Leaf)) {
                throw "Runtime not built. Run: .\Alligator.ps1 -Action Build"
            }
            if (!$selectedGame -or !(Test-Path -LiteralPath $selectedGame -PathType Leaf)) {
                throw 'Game executable not found. Set gameExecutable in config\settings.json or pass -GamePath.'
            }
            $startScript = Join-Path $engineRoot 'ultra\Start-Ultra.ps1'
            $arguments = @{ Profile = $selectedProfile; GamePath = $selectedGame }
            if ($Warmup) { $arguments.Warmup = $true }
            if ($RawLog) { $arguments.RawLog = $true }
            & $startScript @arguments
            break
        }
    }
} catch {
    Write-Host ''
    Write-Error ("Alligator stopped: " + $_.Exception.Message)
    exit 1
}
