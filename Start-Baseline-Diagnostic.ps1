[CmdletBinding()]
param(
    [string]$GamePath
)

$ErrorActionPreference = 'Stop'
$alligator = Join-Path $PSScriptRoot 'Alligator.ps1'

if (!(Test-Path -LiteralPath $alligator -PathType Leaf)) {
    throw "Alligator.ps1 was not found beside this script: $alligator"
}

$arguments = @{
    Action  = 'Launch'
    Profile = 'Baseline'
    RawLog  = $true
}

if (![string]::IsNullOrWhiteSpace($GamePath)) {
    $arguments.GamePath = $GamePath
}

Write-Host 'ALLIGATOR | DIAGNOSTIC BASELINE' -ForegroundColor Cyan
Write-Host 'Profile: Baseline | Raw log: enabled' -ForegroundColor Gray
Write-Host 'This is a diagnostic comparison, not a renderer repair or FPS guarantee.' -ForegroundColor Yellow

& $alligator @arguments
