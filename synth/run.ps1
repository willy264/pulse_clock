[CmdletBinding()]
param(
    [ValidateSet('all', 'pulse_top', 'water_tank_controller')]
    [string]$Top = 'all',
    [string]$QuartusBin = '',
    [string]$Device = 'EP4CE22F17C6'
)
$ErrorActionPreference = 'Stop'
$pulseRepo = Split-Path -Parent $PSScriptRoot
if ($QuartusBin) {
    $pulseQuartus = Join-Path $QuartusBin 'quartus_sh.exe'
} elseif (Get-Command quartus_sh -ErrorAction SilentlyContinue) {
    $pulseQuartus = (Get-Command quartus_sh).Source
} elseif ($env:QUARTUS_ROOTDIR) {
    $pulseQuartus = Join-Path $env:QUARTUS_ROOTDIR 'bin64/quartus_sh.exe'
} else {
    throw 'Set QUARTUS_ROOTDIR, put quartus_sh on PATH, or pass -QuartusBin.'
}
if (-not (Test-Path -LiteralPath $pulseQuartus)) { throw "Quartus executable not found: $pulseQuartus" }
$pulseRun = Join-Path $pulseRepo ('build/quartus/run-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$pulseTops = if ($Top -eq 'all') { @('pulse_top', 'water_tank_controller') } else { @($Top) }
foreach ($pulseTop in $pulseTops) {
    $pulseProject = Join-Path $pulseRun $pulseTop
    New-Item -ItemType Directory -Path $pulseProject -Force | Out-Null
    Push-Location $pulseProject
    try {
        & $pulseQuartus -t (Join-Path $PSScriptRoot 'check.tcl') $pulseRepo $pulseTop $Device 2>&1 |
            Tee-Object -FilePath 'quartus.log'
        if ($LASTEXITCODE -ne 0) { throw "Quartus analysis/synthesis failed for $pulseTop. See $pulseProject" }
    }
    finally { Pop-Location }
}
Write-Output "Artifacts: $pulseRun"
