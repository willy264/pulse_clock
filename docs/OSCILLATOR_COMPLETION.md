# PULSE periodic-generator completion evidence

Date: 2026-09-22. Implementation language: Verilog HDL (Verilog-2001).

The user requested completion of all five assignments, including those previously allocated to teammates. The implemented working choice is **OSC-CONTRACT-1: registered periodic clock-enable ticks**, using the existing documented proposal. This is not a square-wave or physical oscillator. Supervisor acceptance and other teams' interface agreements are not asserted. The [contract](OSCILLATOR_CONTRACT.md) specifies the exact implemented behavior.

## Delivered work

| Assignment | Result and evidence |
| --- | --- |
| OSC-01: specification and explanation | Contract with port/edge tables and frequency calculations; current requirements, interface, timing, architecture, integration, traceability; runnable [demonstration guide](OSCILLATOR_DEMO.md). |
| OSC-02: implementation and developer verification | [pulse_periodic.v](../src/pulse_periodic.v), independent captured reload/count state, and [smoke bench](../tb/pulse_periodic_smoke_tb.v): 35 checks pass. |
| OSC-03: independent verification | [unit bench](../tb/pulse_periodic_tb.v): 9,330 checks; [checker self-test](../tb/pulse_periodic_checker_tb.v): 99 checks with nine deliberately bad samples detected; recorded waveforms and runner failure injection. |
| OSC-04: integration and tools | Extended `pulse_top`, explicit application disable, P08-P11 concurrency cases, 16-source ModelSim/TerosHDL configuration, both Quartus tops checked, baseline and final clean checkouts. |
| OSC-05: review and completion | Separate RTL/test authoring and review, task disposition, source commits, actual run provenance, documentation checks, and limitations recorded here. Human teammate participation or supervisor sign-off is not claimed. |

The user instruction supersedes the earlier assignment deadlines and member allocation. Those administrative handoffs are no longer prerequisites; the technical deliverables have been executed by the coding agent. No unrelated water-tank feature or physical implementation was added.

## Baseline reproduction and source revision

Before modification, a clean local clone of `5e6cb7fb9545ff491aa8aa715dd0709b3ee5d10a` reproduced all four original benches and both synthesis tops. Its source tree matches merged main `1448099` (the merge adds no file changes).

Baseline clone: `C:\Users\HP\AppData\Local\Temp\pulse periodic baseline 5806dfccc7af4648b4144042fe59642e`.

- Simulation: `build/modelsim/run-20260922-101316-753`, relative to that clone; four PASS results with original counts/times.
- Synthesis: `build/quartus/run-20260922-101322-048`; core 224 logic elements/92 registers, application 241/96, warning 20028 only.

The new executable source, tests, scripts, and portable project are committed at **`15857ae6b79d84b10c619ce947af10efca7a1de6`**. Later commits contain documentation and measured review artifacts. The workspace full run preceded only a wording correction to one top-test diagnostic; the final clean checkout below checks the exact committed files.

## ModelSim results

Tool: ModelSim-Altera Starter Edition **10.1d, 2012.11** on Windows. Every source compiles with `vlog -vlog01compat`. No compiler or simulator warnings/errors occurred in the seven positive benches.

Workspace complete regression: `build/modelsim/run-20260922-103440-575`, produced by `./sim/run.ps1` with a new local library and mapping.

| Testbench | Result | Checks/cases | Reported cycles | Finish time |
| --- | --- | --- | --- | --- |
| `pulse_timer_tb` | PASS | 100,985 | 34,206 | 684,131 ns |
| `pulse_debounce_tb` | PASS | 1,000,277 | 1,000,213 | 20,004,271 ns |
| `pulse_periodic_smoke_tb` | PASS | 35 | 35 | 711 ns |
| `pulse_periodic_checker_tb` | PASS | 99; C01-C07; nine expected violations | 49 | 992 ns |
| `pulse_periodic_tb` | PASS | 9,330; O01-O06 | 4,396 | 87,932 ns |
| `pulse_top_tb` | PASS | Original P01-P07 plus P08-P11; no aggregate check count | Not emitted | 2,931 ns |
| `water_tank_system_tb` | PASS | 715; A-G | 684 | 13,671 ns |

Periodic unit checks exhaust configurations 0..15 across at least three periods at width 4; cover width 1, default-width periods 3/4/257/1,000, config changes across reloads, disable/reset mid-period and at expiry, restart, and bounded maximum unsigned configuration behavior. A synchronous consumer counts events on the system clock. The independent checker calculates deadlines from elapsed timestamps modulo the captured period, without reading DUT counters.

The checker-only bench supplies predetermined correct and incorrect schedules. Its nine expected violations prove the checker rejects incorrect observations; they are not design failures. The real-DUT unit run requires zero checker violations.

P08-P11 verify independence during timer requests/cancellation, live configuration changes, sensor noise/qualification, local periodic disable, global disable, and simultaneous timer/periodic expiry. The application disables the new function and its original 127 settled event snapshots match the tracked baseline CSV exactly. Local comparison metadata: `build/periodic_application_comparison.json`.

### Failure detection and diagnostics

The reproducible command `./sim/run.ps1 -Test pulse_periodic_tb -InjectFailure` deliberately fails before `test_passed` is set. Observed workspace evidence: `build/modelsim/run-20260922-102632-929`; the simulator exits **4**, the PowerShell process fails, and no success marker is emitted. A nonzero exit is expected for this command. Normal `-Test all` never enables injection.

Five separate temporary periodic diagnostic probes observed the correct failure and premature stop for width zero, unknown reset, unknown global enable, unknown local enable, and unknown accepted configuration. Artifacts: `C:\Users\HP\AppData\Local\Temp\pulse-periodic-diagnostics-adefaf61ef72462ba31838e8896f1749`. Width zero additionally warns `vsim-8602` about zero replication before its intended guard; it is outside the supported parameter range. These supplementary probes are not part of the seven committed positive benches.

Independent initial unit/checker verification: `C:\Users\HP\AppData\Local\Temp\pulse-periodic-independent-bea0899d89d8490f8fcdec5fb55b703c`. Developer smoke: `C:\Users\HP\AppData\Local\Temp\pulse-periodic-smoke-4d013ae888f04b9ab2b1f40836256b29`. Their results agree with the integrated regression.

## Quartus results

Tool: Quartus II 64-bit **13.0.1 Build 232 SP1 Web Edition**. Workspace run: `build/quartus/run-20260922-102633-279`, using fresh projects, `VERILOG_FILE`, and `VERILOG_INPUT_VERSION VERILOG_2001`.

| Top | Analysis & Synthesis | Estimated logic elements | Registers | Errors | Warnings |
| --- | --- | --- | --- | --- | --- |
| `pulse_top` | PASS | 385 | 158 | 0 | 1 |
| `water_tank_controller` | PASS | 241 | 96 | 0 | 1 |

Core resources increase by 161 estimated logic elements and 66 registers because the independently operating periodic function is exposed at its ports. The application disables it, so the unused function is optimized away and its area is unchanged. Informational logic-cell counts are 387 and 242, a distinct metric from the table. Both runs retain warning **20028**, unavailable licensed parallel compilation; serial compilation succeeds. No latch, multiple-driver, width-truncation, unsupported-construct, or combinational-loop warning was reported. This is synthesis analysis, not fitting or physical timing closure.

## Editor, waveform, and clean-checkout evidence

The portable `pulse.teroshdl.yml` and local `PULSE_Verilog` registration contain all 16 `.v` files and select `pulse_periodic_tb` as the top. Both loaded successfully through installed TerosHDL 7.0.3's actual project loader, with all paths existing, `verilogSource` classification, and ModelSim `-vlog01compat`. Its legacy `2000` version metadata remains as documented in the conversion report. Unrelated local projects/global defaults were preserved; registry backup: `C:\Users\HP\AppData\Local\Temp\pulse-periodic-teros-s14ddxir\.teroshdl2_prj.json`. Reload VS Code if its project list is cached.

The [waveform observations](WAVEFORM_OBSERVATIONS.md) explain the measured smoke, consumer, and concurrency traces. Three CSVs, two PNGs, a reproducible extraction helper, and source hash/size metadata are tracked under `docs/waveforms/`. Both new plots were visually inspected. They are plots of simulator data, not invented timing diagrams or GUI screenshots.

Final clean checkout: `C:\Users\HP\AppData\Local\Temp\pulse periodic final 696fbc152aed4b4c8c5c2c546c752c2f`, cloned from committed executable revision `15857ae6b79d84b10c619ce947af10efca7a1de6` without copied build artifacts. Its path contains spaces and its tracked worktree remains clean.

- `build/modelsim/run-20260922-105734-427`: all seven testbenches PASS with the same check counts and finish times above, with no compilation/simulation warnings or errors.
- `build/quartus/run-20260922-105734-620`: both tops PASS with the same resources; warning 20028 only.

These independent fresh projects/libraries establish that the committed executable sources reproduce the workspace results.

## Completion limits

All software deliverables under OSC-01 through OSC-05 are addressed for the selected tick contract. The pulse output is not a 50% duty square wave; P = 1 is a continuous HIGH enable after the startup interval. A supervisor requirement for a square wave would require a new explicit contract and corresponding implementation/tests.

No external team meeting, teammate-machine run, supervisor acceptance, physical clock accuracy, board fitting/programming, or physical oscillator validation is claimed. Maximum-width full periodic expiry remains unrun; bounded checks and exhaustive reduced-width recurrence provide the recorded evidence. Existing full five-second/max timer completion and the additional cancel-one-cycle-before-expiry test remain separate backlog items, as the original task plan specifies. A code review and finite regression are not formal equivalence or exhaustive fault proof.
