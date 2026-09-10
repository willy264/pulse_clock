# Simulation and RTL-analysis guide

Validated environment: Windows PowerShell, ModelSim-Altera Starter 10.1d (Tcl 8.4.14), and Quartus II 13.0.1 SP1. The exact local installation findings are preserved in [inventory](project_inventory.md). The scripts need no Icarus, Verilator, GTKWave, Vivado, Python, or additional packages.

## 1. Tool discovery and automated simulation

Use `Get-Command vsim` and `vsim -version` to check PATH. From the repository root run:

```powershell
.\sim\run.ps1
.\sim\run.ps1 -Test pulse_timer_tb
.\sim\run.ps1 -ModelSimBin 'C:\your\modelsim\bin'
```

The optional installation directory is local invocation configuration, not a repository hardcoded path. If execution policy blocks a locally reviewed script, a process-local invocation is `powershell -NoProfile -ExecutionPolicy Bypass -File .\sim\run.ps1`; no global policy change is required.

Each invocation creates `build/modelsim/run-<timestamp>` without deleting prior results. It copies a local `modelsim.ini`, creates/maps `work`, compiles SystemVerilog with `vlog -sv`, and loads each selected bench in its own ModelSim process. Design sources compile before dependent wrappers/models/benches; the explicit list is in `sim/compile.do`.

Each bench exposes `test_passed`, sets it only after its checks, then calls `$finish`. ModelSim 10.1d also invokes `onbreak` on a normal finish, so the script resumes the macro and checks that flag. `echo` writes a success marker into the transcript; plain Tcl `puts` is not sufficient for this tool's transcript behavior. The PowerShell runner also rejects Fatal/Error diagnostics and nonzero process exits. A deliberate fatal probe was verified to fail the runner's success check.

The default process timeout is 180 seconds per invocation; change it with `-TimeoutSeconds` if the machine is slower. Testbenches have independent bounded simulation watchdogs. A successful compile alone cannot produce a successful regression result.

## 2. Artifacts and expected results

| Artifact within one run directory | Purpose |
| --- | --- |
| `compile.log` | Complete compile transcript and PULSE_COMPILE_OK marker. |
| `<testbench>.log` | Test checks/case banners, simulator diagnostics, and PULSE_TEST_OK marker. |
| `<testbench>.wlf` | Recorded signals including internal counters and state for GUI review. |
| `water_tank_system.vcd` | Portable recorded application waveform; produced when running that bench. |
| `results.json` | Test names, PASS results, transcript names, and measured runner durations, written only after selected tests succeed. |
| `modelsim.ini`, `work/` | Local simulator mapping and compiled library, never installation-wide settings. |

The expected positive suite is timer, debounce, PULSE top, and water-tank system. Test coverage and limitations are specified in the [verification plan](PULSE_VERIFICATION_PLAN.md); counts are reported in the [final report](FINAL_REPORT.md). Build outputs are ignored by Git.

## 3. Manual ModelSim commands

Create a new working directory with the same three-level layout, then invoke the tools:

```powershell
New-Item -ItemType Directory -Path build/modelsim/manual
Push-Location build/modelsim/manual
vmap -c
vsim -c -l compile.log -do 'source ../../../sim/compile.do; quit -f -code 0'
$env:PULSE_TESTBENCH = 'water_tank_system_tb'
vsim -c -l water_tank_system_tb.log -do 'do ../../../sim/simulate.do'
Remove-Item Env:PULSE_TESTBENCH
Pop-Location
```

Use Tcl `source` for `compile.do`: ModelSim's `do` macro does not populate Tcl `info script` as needed for its repository-relative source discovery. `simulate.do` defaults to `pulse_top_tb` when PULSE_TESTBENCH is unset and accepts only the four known bench names. Check native exit codes when scripting manual commands; the provided PowerShell runner already does so and restores any prior test-selection environment value.

## 4. View waveforms

Open the saved WLF from the ModelSim GUI, or launch a viewer yourself:

```powershell
vsim -view 'build/modelsim/run-<timestamp>/water_tank_system_tb.wlf'
```

In the GUI Transcript, source `sim/wave.do` using its repository path. It adds testbench controls/status and the DUT hierarchy. Inspect clock/reset/enable, start/cancel/configuration, `remaining`, busy/done, sensor input/value/validity; in the application inspect level, source/flow, pump, fault/protection, and controller state. Internal counters are observability points, not public PULSE ports.

WLF time units and the testbenches use a nominal 20 ns clock; application VCD precision is 1 ps. The [waveform observations](WAVEFORM_OBSERVATIONS.md) give measured relationships from a recorded run, including noise rejection and timeout races. Every periodic-output plot is inapplicable to this baseline because the optional extension is absent.

## 5. Quartus analysis and synthesis

```powershell
.\synth\run.ps1
.\synth\run.ps1 -Top pulse_top -QuartusBin 'C:\your\quartus\bin64'
```

Quartus is discovered from an explicit argument, PATH, or `QUARTUS_ROOTDIR`. The runner creates a fresh local project for each selected top under `build/quartus/run-<timestamp>`. It includes only the four synthesizable source files. Testbenches/models and synthesis-excluded diagnostic checks do not become functional hardware.

The default representative analysis device is Cyclone IV E `EP4CE22F17C6`; `-Device` can select another compatible Cyclone IV E part supported by the installation. The example SDC declares the assumed 20 ns input clock. Only Analysis & Synthesis (`quartus_map`) runs. No fitter, timing sign-off, pin assignments, programmer, or physical device is invoked. Reports and warning review are in [synthesis check](SYNTHESIS_CHECK.md).

## 6. TerosHDL and clean-checkout use

The command-line workflow is independent of global editor choices. To use TerosHDL, select ModelSim for this project and import the SystemVerilog files in `compile.do` order, with the desired testbench as simulation top. Do not treat the previously discovered GHDL selection as appropriate for this SV workflow. No global settings were changed by this work.

The repository was also tested in a fresh local Git clone whose directory name contains spaces, using its own empty build directories. That validates tracked source completeness and path handling. Reproduce by cloning the repository, confirming tools, and running the two scripts above; no generated work library or absolute installation mapping needs to be copied.
