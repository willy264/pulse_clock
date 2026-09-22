# Simulation and RTL-analysis guide

Implementation language: Verilog HDL (Verilog-2001).

Validated environment: Windows PowerShell, ModelSim-Altera Starter 10.1d (Tcl 8.4.14), and Quartus II 13.0.1 SP1. The exact local installation findings are preserved in [inventory](project_inventory.md). The scripts need no Icarus, Verilator, GTKWave, Vivado, Python, or additional packages.

## 1. Tool discovery and automated simulation

Use `Get-Command vsim` and `vsim -version` to check PATH. From the repository root run:

```powershell
.\sim\run.ps1
.\sim\run.ps1 -Test pulse_timer_tb
.\sim\run.ps1 -ModelSimBin 'C:\your\modelsim\bin'
```

The optional installation directory is local invocation configuration, not a repository hardcoded path. If execution policy blocks a locally reviewed script, a process-local invocation is `powershell -NoProfile -ExecutionPolicy Bypass -File .\sim\run.ps1`; no global policy change is required.

Each invocation creates `build/modelsim/run-<timestamp>` without deleting prior results. It copies a local `modelsim.ini`, creates/maps `work`, compiles all `.v` sources with `vlog -vlog01compat`, and loads each selected bench in its own ModelSim process. Design sources compile before dependent wrappers/models/benches; the explicit list is in `sim/compile.do`.

Each bench exposes `test_passed`, sets it only after its checks, then calls `$finish`. ModelSim 10.1d also invokes `onbreak` on a normal finish, so the script resumes the macro and checks that flag. `echo` writes a success marker into the transcript; plain Tcl `puts` is not sufficient for this tool's transcript behavior. Verilog failure checks print a `FAIL` diagnostic and call `$stop` before the success flag can be set. The PowerShell runner rejects `FAIL`, Fatal/Error diagnostics, nonzero process exits, and missing success markers. The reproducible command `./sim/run.ps1 -Test pulse_periodic_tb -InjectFailure` deliberately stops before success: the simulator exits 4, the PowerShell process fails, and no success marker appears. The switch is valid only with that focused test; ordinary runs explicitly disable injection and restore the caller's environment afterward.

The default process timeout is 180 seconds per invocation; change it with `-TimeoutSeconds` if the machine is slower. Testbenches have independent bounded simulation watchdogs. A successful compile alone cannot produce a successful regression result.

## 2. Artifacts and expected results

| Artifact within one run directory | Purpose |
| --- | --- |
| `compile.log` | Complete compile transcript and PULSE_COMPILE_OK marker. |
| `<testbench>.log` | Test checks/case banners, simulator diagnostics, and PULSE_TEST_OK marker. |
| `<testbench>.wlf` | Recorded signals including internal counters and state for GUI review. |
| `water_tank_system.vcd` | Portable recorded application waveform; produced when running that bench. |
| `pulse_periodic_smoke_tb.vcd`, `pulse_periodic_tb.vcd`, `pulse_top_tb.vcd` | Recorded startup, recurrence, consumer, and concurrency traces; each produced by its corresponding bench. |
| `results.json` | Test names, PASS results, transcript names, and measured runner durations, written only after selected tests succeed. |
| `modelsim.ini`, `work/` | Local simulator mapping and compiled library, never installation-wide settings. |

The seven-test positive suite comprises `pulse_timer_tb`, `pulse_debounce_tb`, `pulse_periodic_smoke_tb`, `pulse_periodic_checker_tb`, `pulse_periodic_tb`, `pulse_top_tb`, and `water_tank_system_tb`. The checker self-test detects nine intentionally incorrect samples; the real-DUT unit test requires zero checker errors. Test coverage and limitations are specified in the [verification plan](PULSE_VERIFICATION_PLAN.md); counts are reported in the [final report](FINAL_REPORT.md). Build outputs are ignored by Git.

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

Use Tcl `source` for `compile.do`: ModelSim's `do` macro does not populate Tcl `info script` as needed for its repository-relative source discovery. `simulate.do` defaults to `pulse_top_tb` when PULSE_TESTBENCH is unset and accepts only the seven known bench names. Check native exit codes when scripting manual commands; the provided PowerShell runner already does so and restores any prior test-selection environment value.

## 4. View waveforms

Open the saved WLF from the ModelSim GUI, or launch a viewer yourself:

```powershell
vsim -view 'build/modelsim/run-<timestamp>/water_tank_system_tb.wlf'
```

In the GUI Transcript, source `sim/wave.do` using its repository path. It adds testbench controls/status and the DUT hierarchy. Inspect clock/reset/enable, start/cancel/configuration, `remaining`, busy/done, sensor input/value/validity; in the application inspect level, source/flow, pump, fault/protection, and controller state. Internal counters are observability points, not public PULSE ports.

WLF time units and the testbenches use a nominal 20 ns clock; application VCD precision is 1 ps. The [waveform observations](WAVEFORM_OBSERVATIONS.md) give measured relationships from a recorded run, including noise rejection and timeout races. Periodic plots show measured startup/reload/reset, registered-consumer latency, and simultaneous timer/debounce operation. The [oscillator demonstration](OSCILLATOR_DEMO.md) explains the edges and how to regenerate the CSV/PNG evidence with the optional Python helper.

## 5. Quartus analysis and synthesis

```powershell
.\synth\run.ps1
.\synth\run.ps1 -Top pulse_top -QuartusBin 'C:\your\quartus\bin64'
```

Quartus is discovered from an explicit argument, PATH, or `QUARTUS_ROOTDIR`. The runner creates a fresh local project for each selected top under `build/quartus/run-<timestamp>`. It includes only the five synthesizable `.v` source files as `VERILOG_FILE` assignments, with `VERILOG_INPUT_VERSION VERILOG_2001`. Testbenches/models and synthesis-excluded diagnostic checks do not become functional hardware.

The default representative analysis device is Cyclone IV E `EP4CE22F17C6`; `-Device` can select another compatible Cyclone IV E part supported by the installation. The example SDC declares the assumed 20 ns input clock. Only Analysis & Synthesis (`quartus_map`) runs. No fitter, timing sign-off, pin assignments, programmer, or physical device is invoked. Reports and warning review are in [synthesis check](SYNTHESIS_CHECK.md).

## 6. TerosHDL and clean-checkout use

The repository includes [pulse.teroshdl.yml](../pulse.teroshdl.yml), a portable TerosHDL generic-project export with relative paths, all 16 sources in compile order, and `pulse_periodic_tb` as the default top. Import this file through the TerosHDL project manager on another checkout. On this workstation, `PULSE_Verilog` is already registered and selected in `C:\Users\HP\.teroshdl2_prj.json`. Use **Developer: Reload Window** if the current VS Code session has cached the previous project list.

The project selects ModelSim for compilation and Verilog linting, with `-vlog01compat` in both configurations. `.vscode/settings.json` associates `.v` with the Verilog language. The installed TerosHDL 7.0.3 loader recognizes these files as `verilogSource`. Its supported Verilog version metadata labels are `2000` and `2005`; the export uses its legacy `2000` label and explicitly enforces Verilog-2001 through the ModelSim option. Both the portable export and persisted local registration were loaded successfully using the installed extension's project loader. Global tool defaults and unrelated projects were preserved.

The PowerShell runner is the authoritative self-checking regression because it checks the test success flag and transcript. An interactive editor simulation alone does not establish a regression PASS.

The current repository is verified with fresh build directories; the [oscillator completion report](OSCILLATOR_COMPLETION.md) records the latest clean-checkout evidence, including a directory name containing spaces. The [conversion report](VERILOG_CONVERSION.md) preserves the older language-migration evidence. That validates tracked source completeness and path handling. Reproduce by cloning the repository, confirming tools, and running the two scripts above; no generated work library or absolute installation mapping needs to be copied.
