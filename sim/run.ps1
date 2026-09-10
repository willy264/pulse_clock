[CmdletBinding()]
param(
    [ValidateSet('all', 'pulse_timer_tb', 'pulse_debounce_tb', 'pulse_top_tb', 'water_tank_system_tb')]
    [string]$Test = 'all',
    [string]$ModelSimBin = '',
    [ValidateRange(10, 3600)]
    [int]$TimeoutSeconds = 180
)
$ErrorActionPreference = 'Stop'
$pulseRepo = Split-Path -Parent $PSScriptRoot
$pulseVsim = if ($ModelSimBin) { Join-Path $ModelSimBin 'vsim.exe' } else { (Get-Command vsim -ErrorAction Stop).Source }
$pulseVmap = Join-Path (Split-Path -Parent $pulseVsim) 'vmap.exe'
if (-not (Test-Path -LiteralPath $pulseVsim)) { throw "ModelSim executable not found: $pulseVsim" }
$pulseRun = Join-Path $pulseRepo ('build/modelsim/run-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $pulseRun -Force | Out-Null
$pulseTests = if ($Test -eq 'all') { @('pulse_timer_tb', 'pulse_debounce_tb', 'pulse_top_tb', 'water_tank_system_tb') } else { @($Test) }
$pulseResults = @()
$pulseOldTest = $env:PULSE_TESTBENCH

function Invoke-PulseModelSim {
    param([string]$DoCommand, [string]$Label)
    # Arguments below contain only fixed script paths and validated test names.
    $pulseArguments = '-c -l ' + $Label + '.log -wlf ' + $Label + '.wlf -do "' + $DoCommand + '"'
    $pulseProcess = Start-Process -FilePath $pulseVsim -ArgumentList $pulseArguments -WorkingDirectory $pulseRun -WindowStyle Hidden -PassThru
    $pulseStarted = Get-Date
    while (-not $pulseProcess.WaitForExit(1000)) {
        if (((Get-Date) - $pulseStarted).TotalSeconds -gt $TimeoutSeconds) {
            $pulseProcess.Kill()
            $pulseProcess.WaitForExit()
            throw "ModelSim timed out after $TimeoutSeconds seconds: $Label. See $pulseRun"
        }
    }
    $pulseProcess.Refresh()
    if ($pulseProcess.ExitCode -ne 0) {
        Get-Content -LiteralPath (Join-Path $pulseRun ($Label + '.log')) -Tail 45
        throw "ModelSim failed ($($pulseProcess.ExitCode)): $Label. See $pulseRun"
    }
}

Push-Location $pulseRun
try {
    & $pulseVmap -c | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not create a local modelsim.ini.' }
    Invoke-PulseModelSim -DoCommand 'source ../../../sim/compile.do; quit -f -code 0' -Label 'compile'
    foreach ($pulseTest in $pulseTests) {
        $env:PULSE_TESTBENCH = $pulseTest
        $pulseStarted = Get-Date
        Invoke-PulseModelSim -DoCommand 'do ../../../sim/simulate.do' -Label $pulseTest
        $pulseLog = Get-Content -LiteralPath ($pulseTest + '.log') -Raw
        if ($pulseLog -match '\*\*\s+(Fatal|Error):') {
            throw "Simulator error diagnostic in $pulseTest transcript. See $pulseRun"
        }
        if ($pulseLog -match '(?m)^\s*(#\s*)?FAIL\b') {
            throw "Verilog check failure in $pulseTest transcript. See $pulseRun"
        }
        if ($pulseLog -notmatch ('PULSE_TEST_OK ' + [regex]::Escape($pulseTest))) {
            throw "Missing simulator success marker: $pulseTest"
        }
        $pulseResults += [pscustomobject]@{ Testbench = $pulseTest; Result = 'PASS'; Seconds = [math]::Round(((Get-Date) - $pulseStarted).TotalSeconds, 3); Transcript = $pulseTest + '.log' }
        Write-Output "PASS $pulseTest"
    }
    $pulseResults | ConvertTo-Json | Set-Content -LiteralPath 'results.json' -Encoding UTF8
    Write-Output "Artifacts: $pulseRun"
}
finally {
    $env:PULSE_TESTBENCH = $pulseOldTest
    Pop-Location
}
