# Alligator - main control script for DexNom Ultra
# Windows PowerShell 5.1 compatible. The DexNom engine and game remain local.
[CmdletBinding()]
param(
    [ValidateSet('Launch','Build','Doctor','Profiles','Rollback','Report','Collect','Update')]
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
        Write-Host 'Edit config\settings.json to save your game and engine source paths.' -ForegroundColor Gray
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

function Get-EngineSourceRoot($Config, [string]$Override) {
    if (![string]::IsNullOrWhiteSpace($Override)) {
        return Resolve-UserPath $Override
    }
    $configured = Get-Setting $Config 'engineSourceDirectory' '%USERPROFILE%\Downloads\DexNom-UltraPerformance-v0.1'
    return Resolve-UserPath $configured
}

function Get-RuntimeDirectory($Config) {
    $configured = Get-Setting $Config 'runtimeDirectory' $script:RuntimeDefault
    return Resolve-UserPath $configured
}

function Get-SelectedGamePath($Config, [string]$RuntimeDir, [string]$Override) {
    if (![string]::IsNullOrWhiteSpace($Override)) {
        return Resolve-UserPath $Override
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
        'ultra\Enviar-Ultimo-Jogo.ps1',
        'ultra\Collect-Diagnostics.ps1'
    )
    foreach ($relative in $required) {
        $path = Join-Path $Root $relative
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Required DexNom Ultra v0.6 file is missing: $path"
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

function Get-ProfileNames {
    return @(
        'Baseline','Workers4','Preludes','Smooth','VRAM85','Display1080','Display720',
        'Display1080VRAM85','MaterialDemand','MaterialDemand1080','Rehash1080',
        'WideMerge1080','Visibility1080','VisibilityStrong1080','LightingTrace1080',
        'UltraVisual1080','UltraVisualStrong1080','UltraSafe1080','UltraPerf1080',
        'UltraLightingTrace1080'
    )
}

function Get-ProfileDescription {
    return @(
        [pscustomobject]@{ Profile='UltraSafe1080'; Purpose='1080 display mode + visibility lift, without material-demand sampling or long texture bake'; Risk='Recommended first A/B baseline; still an experimental v0.6 presentation profile' },
        [pscustomobject]@{ Profile='UltraPerf1080'; Purpose='Ultra 1080 path + card rehash experiment'; Risk='May not help RX 7600; benchmark separately' },
        [pscustomobject]@{ Profile='Baseline'; Purpose='No Ultra profile-specific renderer tuning'; Risk='Reference run' },
        [pscustomobject]@{ Profile='Display720'; Purpose='Sets title display mode to 1280x720'; Risk='Does not guarantee lower internal render resolution' },
        [pscustomobject]@{ Profile='Workers4'; Purpose='Four workers for eligible fill/upload work'; Risk='Narrow CPU-path experiment' },
        [pscustomobject]@{ Profile='Preludes'; Purpose='Parallel recording of eligible command-list preludes'; Risk='Scene-dependent' },
        [pscustomobject]@{ Profile='Smooth'; Purpose='Disables texture catch-up'; Risk='Can change streaming behaviour' },
        [pscustomobject]@{ Profile='VRAM85'; Purpose='Sets the texture-room percent to 85'; Risk='Memory trade-off; monitor black/missing textures' },
        [pscustomobject]@{ Profile='UltraVisual1080'; Purpose='Material-demand sampling plus 24 ms early texture work and 2500 ms bake window'; Risk='May increase loading and frame work' },
        [pscustomobject]@{ Profile='UltraVisualStrong1080'; Purpose='UltraVisual1080 with stronger visibility lift'; Risk='Visual experiment, not an FPS profile' },
        [pscustomobject]@{ Profile='UltraLightingTrace1080'; Purpose='Extra walls trace and card-accounting diagnostics'; Risk='High diagnostic overhead; not for FPS testing' }
    )
}

try {
    $config = Get-AlligatorConfig
    $engineRoot = Get-EngineSourceRoot $config $SourceRoot
    $runtimeDir = Get-RuntimeDirectory $config
    $selectedGame = Get-SelectedGamePath $config $runtimeDir $GamePath
    $selectedProfile = if (![string]::IsNullOrWhiteSpace($Profile)) { $Profile } else { Get-Setting $config 'defaultProfile' 'UltraSafe1080' }

    if ($selectedProfile -notin (Get-ProfileNames)) {
        throw "Unknown profile '$selectedProfile'. Run .\Alligator.ps1 -Action Profiles to list valid v0.6 profiles."
    }

    switch ($Action) {
        'Profiles' {
            Write-Section 'AVAILABLE v0.6 PROFILES'
            Get-ProfileDescription | Format-Table -Wrap -AutoSize
            Write-Host 'For useful comparisons, keep the same save, camera, scene and cache state.' -ForegroundColor Gray
            break
        }
        'Doctor' {
            Write-Section 'SYSTEM AND FILE CHECK'
            $checks = New-Object 'System.Collections.Generic.List[object]'
            $checks.Add([pscustomobject]@{Check='Windows x64';Status=$(if ([Environment]::Is64BitOperatingSystem -and $env:OS -eq 'Windows_NT') {'OK'} else {'CHECK'});Detail=[Environment]::OSVersion.VersionString})
            $checks.Add([pscustomobject]@{Check='Git';Status=$(if (Get-Command git -ErrorAction SilentlyContinue) {'OK'} else {'CHECK'});Detail='Required for Alligator self-update'})
            $checks.Add([pscustomobject]@{Check='Rust Cargo';Status=$(if (Get-Command cargo -ErrorAction SilentlyContinue) {'OK'} else {'CHECK'});Detail='Needed only when rebuilding the engine'})
            $checks.Add([pscustomobject]@{Check='DexNom source directory';Status=$(if (Test-Path -LiteralPath $engineRoot -PathType Container) {'OK'} else {'CHECK'});Detail=$engineRoot})
            foreach ($relative in 'ultra\Build-Ultra.ps1','ultra\Start-Ultra.ps1','ultra\Live-Monitor.ps1','ultra\Enviar-Ultimo-Jogo.ps1','ultra\Collect-Diagnostics.ps1','Initialize-FormatTables.ps1') {
                $path = Join-Path $engineRoot $relative
                $checks.Add([pscustomobject]@{Check=$relative;Status=$(if (Test-Path -LiteralPath $path -PathType Leaf) {'OK'} else {'CHECK'});Detail=$path})
            }
            $checks.Add([pscustomobject]@{Check='Runtime directory';Status=$(if (Test-Path -LiteralPath $runtimeDir -PathType Container) {'OK'} else {'CHECK'});Detail=$runtimeDir})
            foreach ($name in 'victory.exe','victory-play.exe','victory-warm.exe') {
                $path = Join-Path $runtimeDir $name
                $checks.Add([pscustomobject]@{Check=$name;Status=$(if (Test-Path -LiteralPath $path -PathType Leaf) {'OK'} else {'CHECK'});Detail=$path})
            }
            $gameOk = $selectedGame -and (Test-Path -LiteralPath $selectedGame -PathType Leaf)
            $checks.Add([pscustomobject]@{Check='Game executable';Status=$(if ($gameOk) {'OK'} else {'CHECK'});Detail=$(if ($selectedGame) {$selectedGame} else {'Not configured'})})
            try {
                $gpuNames = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | Select-Object -ExpandProperty Name)
                $checks.Add([pscustomobject]@{Check='GPU detection';Status=$(if ($gpuNames.Count -gt 0) {'OK'} else {'CHECK'});Detail=($gpuNames -join '; ')})
            } catch {
                $checks.Add([pscustomobject]@{Check='GPU detection';Status='CHECK';Detail=$_.Exception.Message})
            }
            $checks | Format-Table -AutoSize -Wrap
            Write-Host 'Doctor checks files and prerequisites only; it does not certify compatibility or performance.' -ForegroundColor Gray
            break
        }
        'Build' {
            Write-Section 'BUILD DEXNOM ULTRA v0.6'
            Assert-EngineSource $engineRoot
            Assert-RuntimeClosed
            $buildScript = Join-Path $engineRoot 'ultra\Build-Ultra.ps1'
            if ($selectedGame) {
                if (!(Test-Path -LiteralPath $selectedGame -PathType Leaf)) { throw "Game executable not found: $selectedGame" }
                & $buildScript -GamePath $selectedGame
            } else {
                & $buildScript
            }
            Write-Host 'Original v0.6 build script completed; its own binary backup/rollback logic remains in control.' -ForegroundColor Green
            break
        }
        'Rollback' {
            Write-Section 'ROLL BACK RUNTIME BINARIES'
            Assert-EngineSource $engineRoot
            Assert-RuntimeClosed
            & (Join-Path $engineRoot 'ultra\Build-Ultra.ps1') -Rollback
            break
        }
        'Report' {
            Write-Section 'EXPORT LAST SESSION REPORT'
            Assert-EngineSource $engineRoot
            & (Join-Path $engineRoot 'ultra\Enviar-Ultimo-Jogo.ps1') -SourceRoot $engineRoot -RuntimeDir $runtimeDir -OutputDir (Join-Path $env:USERPROFILE 'Downloads') -NoQuestions
            break
        }
        'Collect' {
            Write-Section 'COLLECT RUNTIME DIAGNOSTICS'
            Assert-EngineSource $engineRoot
            & (Join-Path $engineRoot 'ultra\Collect-Diagnostics.ps1') -RuntimeDir $runtimeDir
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
