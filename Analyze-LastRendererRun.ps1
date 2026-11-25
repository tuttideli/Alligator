[CmdletBinding()]
param(
    [string]$RuntimeDir = (Join-Path $env:LOCALAPPDATA 'DexNom Ultra Performance v0.1'),
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$logDir = Join-Path $RuntimeDir 'logs'

if (!(Test-Path -LiteralPath $logDir -PathType Container)) {
    throw "Runtime log directory not found: $logDir"
}

$latest = Get-ChildItem -LiteralPath $logDir -Filter 'run-*.log' -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if ($null -eq $latest) {
    throw "No run-*.log files found in: $logDir"
}

Write-Host "Analyzing latest runtime log: $($latest.Name)" -ForegroundColor Cyan
$lines = @(Get-Content -LiteralPath $latest.FullName)

function Convert-InvariantDouble([string]$Value) {
    return [double]::Parse($Value, [Globalization.CultureInfo]::InvariantCulture)
}

function Format-Invariant([double]$Value) {
    return $Value.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture)
}

function Get-Median([double[]]$Values) {
    $sorted = @($Values | Sort-Object)
    if ($sorted.Count -eq 0) { return [double]::NaN }
    $middle = [int][Math]::Floor($sorted.Count / 2)
    if (($sorted.Count % 2) -eq 1) { return [double]$sorted[$middle] }
    return (([double]$sorted[$middle - 1] + [double]$sorted[$middle]) / 2.0)
}

$frames = New-Object 'System.Collections.Generic.List[object]'
$memory = New-Object 'System.Collections.Generic.List[object]'
$streams = New-Object 'System.Collections.Generic.List[object]'

$framePattern = '^\[FRAME\]\s+(?<fps>\d+(?:\.\d+)?)\s+FPS\s+\|\s+(?<ms>\d+(?:\.\d+)?)\s+ms\s+\|\s+CPU prep\s+(?<cpu>\d+(?:\.\d+)?)\s+ms\s+\|\s+GPU wait\s+(?<gpu>\d+(?:\.\d+)?)\s+ms\s+\|\s+copy-back\s+(?<copy>\d+(?:\.\d+)?)\s+ms\s+\|\s+draws\s+(?<draws>\d+)\s+\|\s+dropped\s+(?<dropped>\d+)\s+\|\s+texturas pendentes\s+(?<pending>\d+)'
$memoryPattern = '^\[MEM\]\s+Local\s+(?<used>\d+)/(?<budget>\d+)\s+MiB\s+\|\s+Nao local\s+(?<nonlocal>\d+)/(?<nonbudget>\d+)\s+MiB'
$streamPattern = '^\[STREAM\]\s+Fila\s+(?<queue>\d+)\s+\|\s+prontas\s+(?<ready>\d+)\s+\|\s+memoria ainda nao mapeada\s+(?<unmapped>\d+)\s+\|\s+parciais\s+(?<partial>\d+)'

foreach ($line in $lines) {
    $match = [regex]::Match($line, $framePattern)
    if ($match.Success) {
        $frames.Add([pscustomobject]@{
            Fps = Convert-InvariantDouble $match.Groups['fps'].Value
            FrameMs = Convert-InvariantDouble $match.Groups['ms'].Value
            CpuMs = Convert-InvariantDouble $match.Groups['cpu'].Value
            GpuWaitMs = Convert-InvariantDouble $match.Groups['gpu'].Value
            CopyBackMs = Convert-InvariantDouble $match.Groups['copy'].Value
            Draws = [int]$match.Groups['draws'].Value
            Dropped = [int]$match.Groups['dropped'].Value
            PendingTextures = [int]$match.Groups['pending'].Value
        })
        continue
    }

    $match = [regex]::Match($line, $memoryPattern)
    if ($match.Success) {
        $memory.Add([pscustomobject]@{
            LocalUsedMiB = [int]$match.Groups['used'].Value
            LocalBudgetMiB = [int]$match.Groups['budget'].Value
            NonLocalUsedMiB = [int]$match.Groups['nonlocal'].Value
            NonLocalBudgetMiB = [int]$match.Groups['nonbudget'].Value
        })
        continue
    }

    $match = [regex]::Match($line, $streamPattern)
    if ($match.Success) {
        $streams.Add([pscustomobject]@{
            Queue = [int]$match.Groups['queue'].Value
            Ready = [int]$match.Groups['ready'].Value
            Unmapped = [int]$match.Groups['unmapped'].Value
            Partial = [int]$match.Groups['partial'].Value
        })
    }
}

$heavyFrames = @($frames | Where-Object { $_.Draws -ge 500 })
$maxPending = 0
if ($frames.Count -gt 0) {
    $maxPending = [int](($frames | Measure-Object -Property PendingTextures -Maximum).Maximum)
}
$maxDropped = 0
if ($heavyFrames.Count -gt 0) {
    $maxDropped = [int](($heavyFrames | Measure-Object -Property Dropped -Maximum).Maximum)
}
$bufferViewWarnings = @($lines | Where-Object { $_ -match 'buffer views left null: raw, refused by the host' }).Count
$maxUnmapped = 0
if ($streams.Count -gt 0) {
    $maxUnmapped = [int](($streams | Measure-Object -Property Unmapped -Maximum).Maximum)
}
$maxLocalUsed = 0
$maxLocalBudget = 0
if ($memory.Count -gt 0) {
    $maxLocalUsed = [int](($memory | Measure-Object -Property LocalUsedMiB -Maximum).Maximum)
    $maxLocalBudget = [int](($memory | Measure-Object -Property LocalBudgetMiB -Maximum).Maximum)
}

$gpuNames = @()
$cpuNames = @()
$ramGiB = 'unavailable'
try {
    $gpuNames = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | Select-Object -ExpandProperty Name)
} catch {}
try {
    $cpuNames = @(Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -ExpandProperty Name)
} catch {}
try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $ramGiB = Format-Invariant ([double]$os.TotalVisibleMemorySize / 1MB)
} catch {}

$eventsPattern = 'buffer views left null|without a host pipeline|host pipeline refused|root signature|failed to translate|translation failed|shader.{0,30}(error|failed|refused)|device removed|out of memory|out-of-memory|OOM|unmapped'
$events = @($lines | Where-Object { $_ -match $eventsPattern } | Select-Object -Last 80)
$events = @($events | ForEach-Object {
    $_ -replace '(?i)C:\\Users\\[^\\\s"]+', 'C:\Users\<USER>'
})

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path (Join-Path $env:USERPROFILE 'Downloads') "Alligator-Renderer-Diagnostic-$stamp.txt"
}
$outputDirectory = Split-Path -Parent $OutputPath
if (!(Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$report = New-Object 'System.Collections.Generic.List[string]'
$report.Add('ALLIGATOR | RENDERER DIAGNOSTIC SUMMARY')
$report.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$report.Add("Log file: $($latest.Name)")
$report.Add("Log updated: $($latest.LastWriteTime)")
$report.Add('')
$report.Add('HARDWARE')
$report.Add("GPU: $($gpuNames -join '; ')")
$report.Add("CPU: $($cpuNames -join '; ')")
$report.Add("Visible system RAM: $ramGiB GiB")
$report.Add('')
$report.Add('RENDERER COUNTERS')
$report.Add("Frame samples parsed: $($frames.Count)")
$report.Add("Heavy-scene samples (draws >= 500): $($heavyFrames.Count)")
if ($heavyFrames.Count -gt 0) {
    $medianFps = Get-Median ([double[]]@($heavyFrames | ForEach-Object { $_.Fps }))
    $medianFrameMs = Get-Median ([double[]]@($heavyFrames | ForEach-Object { $_.FrameMs }))
    $minFps = [double](($heavyFrames | Measure-Object -Property Fps -Minimum).Minimum)
    $maxDraws = [int](($heavyFrames | Measure-Object -Property Draws -Maximum).Maximum)
    $report.Add("Heavy-scene median FPS: $(Format-Invariant $medianFps)")
    $report.Add("Heavy-scene median frame time: $(Format-Invariant $medianFrameMs) ms")
    $report.Add("Heavy-scene minimum FPS: $(Format-Invariant $minFps)")
    $report.Add("Maximum draws in heavy-scene samples: $maxDraws")
    $report.Add("Maximum dropped draws in heavy-scene samples: $maxDropped")
} else {
    $report.Add('No heavy-scene samples were found. The log may cover only menus/loading or an incomplete run.')
}
$report.Add("Maximum pending texture count: $maxPending")
$report.Add("Maximum unmapped texture count in STREAM samples: $maxUnmapped")
$report.Add("Buffer-view refusal warning lines: $bufferViewWarnings")
$report.Add("Local-memory peak: $maxLocalUsed / $maxLocalBudget MiB")
if ($maxLocalBudget -gt 0 -and $maxLocalUsed -gt $maxLocalBudget) {
    $report.Add('WARNING: the reported local-memory use exceeded the displayed local-memory budget.')
}
$report.Add('')
$report.Add('SELECTED GRAPHICS / RESOURCE EVENTS (last 80 matching lines)')
if ($events.Count -gt 0) {
    foreach ($event in $events) { $report.Add($event) }
} else {
    $report.Add('No matching warning lines were found by the current filters.')
}
$report.Add('')
$report.Add('This summary is diagnostic only. It does not prove one root cause or patch the renderer.')
$report.Add('Review local paths before sharing. No game files, saves, shader caches or memory dumps are copied.')

$report | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host ''
Write-Host 'Diagnostic summary created:' -ForegroundColor Green
Write-Host $OutputPath -ForegroundColor Cyan
Write-Host "Frame samples: $($frames.Count) | Heavy-scene samples: $($heavyFrames.Count) | Max pending textures: $maxPending | Buffer-view warning lines: $bufferViewWarnings"
