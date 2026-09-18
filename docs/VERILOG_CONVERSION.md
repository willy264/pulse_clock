# Verilog HDL conversion and verification

Date: 2026-09-10. Status: **Conversion complete; clean simulation and Quartus Analysis & Synthesis passed.**

Implementation language: Verilog HDL (Verilog-2001).

## 1. Reason and scope

The user corrected the implementation-language requirement to Verilog HDL for the existing Windows, VS Code, TerosHDL, Intel Quartus 13.0.1, and ModelSim-Altera 10.1d environment. This supersedes the original language choice. The previous SystemVerilog baseline is retained in Git at `a245bab`; the converted executable RTL, models, benches, scripts, and editor configuration are committed at `c9c9016d3703e60e37317406c354b07f4bde38f0`. Later documentation commits do not change those tested inputs.

Every one of the 11 previous `.sv` files was reviewed for language compatibility, driver types, widths/signedness, procedural scheduling, diagnostic behavior, and test intent. The conversion preserves module boundaries, ports, defaults, clock/reset/enable behavior, timer priority and deadlines, debounce acquisition/stability timing, controller policy, numerical state encodings, and pump/tank/sensor models. No features or architectural changes were introduced. Work stops after this conversion and verification.

## 2. Files converted

The previous filenames below are conversion history; all current build inputs use the corresponding `.v` file.

| Previous file | Current file | Role |
| --- | --- | --- |
| `src/pulse_timer.sv` | [src/pulse_timer.v](../src/pulse_timer.v) | Synthesizable one-shot timer. |
| `src/pulse_debounce.sv` | [src/pulse_debounce.v](../src/pulse_debounce.v) | Synchronizer and independent stability qualifier. |
| `src/pulse_top.sv` | [src/pulse_top.v](../src/pulse_top.v) | Timer and generated sensor channels. |
| `src/application/water_tank_controller.sv` | [src/application/water_tank_controller.v](../src/application/water_tank_controller.v) | Synthesizable demonstration controller. |
| `tb/models/pump_model.sv` | [tb/models/pump_model.v](../tb/models/pump_model.v) | Digital pump/flow model; its source already used compatible net declarations and continuous assignment. |
| `tb/models/sensor_model.sv` | [tb/models/sensor_model.v](../tb/models/sensor_model.v) | Threshold/noise model. |
| `tb/models/water_tank_model.sv` | [tb/models/water_tank_model.v](../tb/models/water_tank_model.v) | Discrete fill/drain model. |
| `tb/pulse_timer_tb.sv` | [tb/pulse_timer_tb.v](../tb/pulse_timer_tb.v) | Timer tests. |
| `tb/pulse_debounce_tb.sv` | [tb/pulse_debounce_tb.v](../tb/pulse_debounce_tb.v) | Debounce tests and counter-width boundaries. |
| `tb/pulse_top_tb.sv` | [tb/pulse_top_tb.v](../tb/pulse_top_tb.v) | PULSE integration tests. |
| `tb/water_tank_system_tb.sv` | [tb/water_tank_system_tb.v](../tb/water_tank_system_tb.v) | Application scenarios A-G. |

## 3. Constructs removed or replaced

This table describes changes from the previous SystemVerilog implementation.

| Previous construct | Verilog replacement and compatibility detail |
| --- | --- |
| `logic`, including typed local parameters and task arguments | `reg` for procedural assignments; `wire` for inputs, continuous assignments, and child-driven outputs. Packed local parameters retain explicit widths. |
| `always_ff` | `always @(posedge clk)` with the original nonblocking assignments and sequential ownership. |
| `always_comb` | `always @(*)`, preserving complete combinational defaults and sensitivity to the inputs used by the controller. |
| `typedef enum logic [1:0]` | Two-bit `localparam` constants and `reg [1:0] state`/next-state declarations. Debounce encodings remain 00/01/10 and controller encodings remain 00/01/10/11. |
| Unsized unbased literal `'0` | Explicit width-sized zero replications, including parameterized vector initialization and comparisons. |
| `$clog2` for debounce width | Verilog-2001 constant function `inclusive_count_width`. It counts shifts of positive D and computes the inclusive 0..D width without overflowing D+1 at INT_MAX. |
| Immediate `assert ... else` | Procedural `if ((condition) !== 1'b1)` failure checks. False and unknown conditions still fail. Existing synthesis exclusion remains in place. |
| `$fatal` | `$display("FAIL ...")` followed by `$stop`. The ModelSim macro requires `test_passed = 1`, and the PowerShell runner rejects failure diagnostics, bad exit status, or missing success markers. |
| Testbench `string` arguments | Packed 256-byte task inputs and `%0s` display formatting. The longest existing literal is 90 bytes, so no existing message is truncated. |
| No-argument task calls with empty parentheses | Standard task enable syntax, for example `tick;`. Multi-statement task bodies are enclosed in `begin`/`end`. |
| `$bits` testbench checks | A leading one-bit sentinel concatenated with the actual counter and shifted by the expected width. This retains all four structural-width checks without reading unknown counter contents as data or duplicating the implementation's width parameter. |
| Sensor-model `input integer level` port | `input wire signed [31:0] level`, retaining signed 32-bit connectivity from the tank's valid Verilog `output integer level`. |

Existing `parameter integer`, `localparam integer`, `task automatic`, ANSI ports/tasks, generate loops, declaration initialization in simulation code, signed arithmetic, and nonblocking assignments are supported by Verilog-2001 and were retained where appropriate. No packages, interfaces, structs, classes, dynamic arrays, or additional assertion-language dependencies were present. No synthesizable functional delays, simulation clock generation, or file I/O were added.

## 4. Tool and configuration changes

| File or setting | Current behavior |
| --- | --- |
| [sim/compile.do](../sim/compile.do) | Lists all 11 `.v` files in dependency order and uses `vlog -vlog01compat -work work`. |
| [sim/simulate.do](../sim/simulate.do) | Handles completion/break behavior in ModelSim 10.1d, inspects each bench's success flag, and returns a failing exit status if a check stops first. |
| [sim/run.ps1](../sim/run.ps1) | Builds a fresh library per run, runs isolated benches, rejects `FAIL` diagnostics as well as simulator errors, and retains watchdog/process-timeout checks. |
| [synth/check.tcl](../synth/check.tcl) | Creates Quartus projects with four `VERILOG_FILE` assignments and `VERILOG_INPUT_VERSION VERILOG_2001`. |
| [pulse.teroshdl.yml](../pulse.teroshdl.yml) | Portable relative-path project export, all 11 files classified as `verilogSource`, ModelSim selected, `-vlog01compat` configured for compilation and linting, application bench selected as top. JSON formatting is valid YAML. |
| [.vscode/settings.json](../.vscode/settings.json) | Maps `*.v` to the Verilog language and selects the installed TerosHDL formatter. |
| README and documentation | Current source links, commands, implementation descriptions, requirements, waveform metadata, and verification provenance describe Verilog HDL. |

The installed TerosHDL 7.0.3 implementation exposes Verilog version metadata labels `2000` and `2005`; it has no `2001` label. The project uses the accepted legacy `2000` metadata label and explicitly selects actual Verilog-2001 compatibility using `-vlog01compat`. The installed extension's project loader successfully loaded both the portable export and the persisted local registration, resolved all 11 paths, classified them as Verilog, and selected the configured top and ModelSim options.

On this workstation, `PULSE_Verilog` was added and selected in `C:\Users\HP\.teroshdl2_prj.json`; existing unrelated projects and global defaults were preserved. Its prior registry was backed up to `C:\Users\HP\AppData\Local\Temp\pulse-teros-verilog-backup-4v_t3exy\.teroshdl2_prj.json`. If the running editor has cached the previous project list, use **Developer: Reload Window**. Another checkout can import the tracked portable project. GUI clicking or waveform inspection inside TerosHDL was not used as verification evidence.

## 5. Clean ModelSim compilation and regression

Simulator/compiler: **ModelSim-Altera Starter Edition 10.1d, 2012.11**, using the installed Windows tools. Compilation uses `vlog -vlog01compat`; no extended-language compiler option is required.

Executed `./sim/run.ps1` from the repository. The runner created `build/modelsim/run-20260910-065458-111` with a new local `modelsim.ini` and newly compiled `work` library. No previously compiled HDL artifacts were reused. Previous ignored build directories were retained solely as historical evidence.

All 11 sources compiled successfully with **zero errors and no warnings**. All four existing positive benches passed:

| Bench | Checks / scenarios | Sampled cycles reported | Finish time | Comparison with prior baseline |
| --- | --- | --- | --- | --- |
| `pulse_timer_tb` | 100,985 checks | 34,206 | 684,131 ns | Same counts, time, and PASS. |
| `pulse_debounce_tb` | 1,000,277 checks | 1,000,213 | 20,004,271 ns | Same counts, time, and PASS. |
| `pulse_top_tb` | P01-P07; no numerical total emitted | Not emitted | 1,931 ns | Same scenarios, time, and PASS. |
| `water_tank_system_tb` | 715 checks; scenarios A-G | 684 | 13,671 ns | Same counts, time, and PASS. |

The timer suite retains exhaustive completion of all 256 configurations of an 8-bit timer. Debounce retains its full default 1,000,000-cycle interval and width checks at D = 1, 4, 1,000,000, and 2,147,483,647. Integration/application cases retain concurrency, noise, timeout, clear, reset, disable, and response/expiry races. Detailed case IDs and limitations remain in [PULSE_VERIFICATION_PLAN.md](PULSE_VERIFICATION_PLAN.md).

The application VCD was extracted using the existing waveform helper and compared to the tracked baseline CSV: **all 127 settled transition snapshots are identical**, including timestamps, controller states, pump/flow, timer, sensor, and control values. Evidence is recorded locally in `build/verilog_trace_comparison.json`; the new VCD hash and measurements are in [WAVEFORM_OBSERVATIONS.md](WAVEFORM_OBSERVATIONS.md). This comparison supports preserved observed behavior; it is not formal equivalence over every possible input.

An independent temporary-library compile and four-bench regression also passed under `C:\Users\HP\AppData\Local\Temp\pulse-verilog-bench-d98df18a568e4174b9517b863f0ba81a`.

### Failure-path and language-mode verification

Temporary Verilog probes under `C:\Users\HP\AppData\Local\Temp\pulse-verilog-diagnostics-3b18d728f1b04b5583b11da343865f63` tested W = 0, S = 0, D = 0, D = -1, and reset/enable individually unknown on each timer/debounce. **All eight emitted the expected `FAIL` diagnostic and stopped before the end marker.**

A temporary application-bench copy deliberately failed an existing check immediately before the success flag. The unchanged simulation macro returned **exit 4**, with `test_passed = 0` and no `PULSE_TEST_OK`. Normal benches returned exit 0. A separate temporary `.v` source containing a SystemVerilog `logic` declaration was rejected by `vlog -vlog01compat` with a syntax error and exit 2, confirming that the positive build did not succeed by silently enabling that language.

Only the intentionally invalid W = 0 fixture also emitted ModelSim `vsim-8602` about a zero replication multiplier before its intended parameter diagnostic. It is not a warning in any supported configuration. Temporary probes were kept outside the source tree; no permanent test cases or new design features were added.

### Fresh tracked checkout

A fresh local Git clone at `C:\Users\HP\AppData\Local\Temp\pulse Verilog clean validation 08e9035effda424d9f74baa2c85da0b3` checked out executable revision `c9c9016d3703e60e37317406c354b07f4bde38f0`. It had no build directory before validation. Its directory name contains spaces, exercising script path handling.

| Command from clone root | Fresh artifact directory relative to clone | Result |
| --- | --- | --- |
| `./sim/run.ps1 -Test all` | `build/modelsim/run-20260910-070543-875` | All 11 sources compiled; all four benches PASS with the same counts and finish times, no warnings/errors. |
| `./synth/run.ps1 -Top all -QuartusBin C:/altera/13.0sp1/quartus/bin64` | `build/quartus/run-20260910-070543-799` | Both tops PASS, zero errors and warning 20028 each; identical resource counts. |

All portable TerosHDL source paths and the top resolve within the clone, with every source classified as `verilogSource`. The clone's tracked working tree remained clean after both commands. This confirms the committed inputs work with new libraries/databases and without copying any prior compiled artifacts.

## 6. Quartus verification

Tool: **Quartus II 64-bit 13.0.1 Build 232 SP1 Web Edition**. Executed `./synth/run.ps1` against both default-parameter production tops. A fresh project/database was generated for each in `build/quartus/run-20260910-065547-884`; inspection of the generated QSF confirms the Verilog input mode and `.v` paths.

| Top | Result | Estimated logic elements | Registers | Errors | Warnings |
| --- | --- | --- | --- | --- | --- |
| `pulse_top` | Analysis & Synthesis PASS | 224 | 92 | 0 | 1 |
| `water_tank_controller` | Analysis & Synthesis PASS | 241 | 96 | 0 | 1 |

All resource counts match the previous implementation. The only warning in each run is **20028: parallel compilation is not licensed and has been disabled**; compilation proceeds serially. The application also retains informational optimization 17049 for two state registers losing fanouts. No syntax, width mismatch/truncation, multiple-driver, inferred-latch, unsupported-construct, or combinational-loop warning was reported by the valid builds.

The existing scope is Analysis & Synthesis for representative Cyclone IV E `EP4CE22F17C6`. A fitter, board pin assignment, programming image, physical timing closure, and hardware tests are outside this conversion. See [SYNTHESIS_CHECK.md](SYNTHESIS_CHECK.md) for report-field distinctions and reproducible commands.

## 7. Remaining issues and limitations

There are no outstanding Verilog conversion errors or failing existing testbenches. The licensing warning and invalid-only diagnostic warning above are accounted for. Full 32-bit maximum and full 5-second timer expiration remain unexecuted, while capture/decrement/cancel and all reduced-width durations are verified. INT_MAX debounce is a width/elaboration check; the full default 20 ms debounce was run. External team contracts and physical model assumptions remain provisional. These are unchanged baseline limits, detailed in [KNOWN_ISSUES.md](KNOWN_ISSUES.md).

Final review also checked all 18 Markdown documents, 164 local file links, table columns, code fences, UTF-8/newline integrity, current HDL/configuration references, and Git whitespace checks. The executable files remain identical to the tested conversion commit.

## 8. Exact current project structure

The following is the complete 42-file tracked project tree at conversion delivery on 2026-09-10, including this report. Later project documents may add files; this tree preserves the conversion snapshot. Generated simulator/Quartus data are separate ignored outputs under `build/`; `.git/` holds version history. Neither is an input dependency. The temporary diagnostics, clean clone, and workstation TerosHDL registry are outside this repository.

```text
pulse_clock/
|-- .vscode/
|   `-- settings.json
|-- docs/
|   |-- waveforms/
|   |   |-- application_events.csv
|   |   |-- application_timing.png
|   |   `-- extract_application_waveforms.py
|   |-- FINAL_REPORT.md
|   |-- FUTURE_HARDWARE_IMPLEMENTATION.md
|   |-- INTEGRATION_CONTRACT.md
|   |-- KNOWN_ISSUES.md
|   |-- project_inventory.md
|   |-- PULSE_ARCHITECTURE.md
|   |-- PULSE_INTERFACE.md
|   |-- PULSE_REQUIREMENTS.md
|   |-- PULSE_STATE_MACHINES.md
|   |-- PULSE_TIMING_SPEC.md
|   |-- PULSE_VERIFICATION_PLAN.md
|   |-- SIMULATION_GUIDE.md
|   |-- SYNTHESIS_CHECK.md
|   |-- TRACEABILITY_MATRIX.md
|   |-- VERILOG_CONVERSION.md
|   |-- WATER_TANK_BEHAVIOR.md
|   `-- WAVEFORM_OBSERVATIONS.md
|-- sim/
|   |-- compile.do
|   |-- run.ps1
|   |-- simulate.do
|   `-- wave.do
|-- src/
|   |-- application/
|   |   `-- water_tank_controller.v
|   |-- pulse_debounce.v
|   |-- pulse_timer.v
|   `-- pulse_top.v
|-- synth/
|   |-- check.tcl
|   |-- pulse.sdc
|   `-- run.ps1
|-- tb/
|   |-- models/
|   |   |-- pump_model.v
|   |   |-- sensor_model.v
|   |   `-- water_tank_model.v
|   |-- pulse_debounce_tb.v
|   |-- pulse_timer_tb.v
|   |-- pulse_top_tb.v
|   `-- water_tank_system_tb.v
|-- .gitignore
|-- pulse.teroshdl.yml
`-- README.md
```

All current HDL implementation, model, and testbench sources are **pure Verilog HDL**: four production files, three simulation models, and four benches, all using `.v`. There are no current `.sv`/`.svh` source files or active configuration dependencies on them. Historical references exist only in this conversion record, Git history, and retained ignored preconversion build evidence. PowerShell, Tcl, Python, Markdown, and configuration files remain the project's normal automation and documentation.
