# PULSE verification plan

Prepared: 2026-09-10. Status: **Functional regression and structural RTL/synthesis checks complete; final delivery review is tracked in the [final report](FINAL_REPORT.md).** The working digital contract is provisional for external integration. Recorded PASS results below apply only to the stated checks and limits.

## 1. Scope and acceptance method

Verify the independent one-shot, individual sensor qualifier, their composition, and the provisional GUARDIAN demonstration. The acceptance oracle is the edge behavior in [timing](PULSE_TIMING_SPEC.md), [state machines](PULSE_STATE_MACHINES.md), and [water-tank behavior](WATER_TANK_BEHAVIOR.md). [Traceability](TRACEABILITY_MATRIX.md) maps every functional and non-functional requirement to these checks or to review/delivery evidence.

All functional fixtures use a 20 ns clock period, corresponding to an illustrative 50 MHz. Stimulus is normally driven on falling edges; outputs are checked after rising-edge registered updates. Timers are judged against elapsed edge numbers, and debounce is judged against the first raw capture plus the documented acquisition/qualification delay. Assertions additionally check internal invariants. These assertions supplement public-output checks rather than replace them.

Each committed bench has a `test_passed` marker initialized to zero, fatal self-check failures, a bounded simulation watchdog, and a completion message. It sets the marker only after its required checks. A successful run requires successful compilation/elaboration, normal completion, marker one, and no error/fatal diagnostic. The host runner also imposes a wall-clock timeout.

The labels P-001 through P-037 below are document-level verification IDs. T01–T08, D00–D08, P01–P07, and A–G are labels in the corresponding benches. In particular, top-level bench label P01 is distinct from document ID P-001.

## 2. Fixtures and practical range coverage

| Fixture | Configuration | What is exercised | Limit |
| --- | --- | --- | --- |
| Timer reduced width | W = 8; every configuration 0…255 | Every configured duration completes; zero normalization, exact busy/done edges, and one-cycle done. | Exhaustive over this 8-bit configuration domain only; not every possible control sequence. |
| Timer minimum width | W = 1; both representable values | Zero and one both expire one complete interval after start. | This establishes the minimum legal width, not arbitrary-width formal equivalence. |
| Timer default width | W = 32; 0 and 1,000 cycles complete | Default-width zero behavior and representative 20 us completion. | The 1,000-cycle run is not the illustrative 5 s application window. |
| Timer long configurations | W = 32; 250,000,000 and 4,294,967,295 cycles | Capture without truncation/overflow, an unsigned decrement, and cancellation. | Neither the 5 s window nor the 85.8993459 s maximum is simulated to completion. |
| Debounce small/minimum | D = 4 and D = 1 | Full startup/change deadlines, both directions, chatter, and mismatch exactly at expiry. D = 4 also exercises a power-of-two inclusive counter boundary. | Digital captured samples only; no analog-glitch or metastability model. |
| Debounce default | D = 1,000,000 | Full 20 ms stability interval plus acquisition latency; every pre-deadline observation remains invalid. | This is a complete nominal debounce run, not a shortened fixture. |
| Debounce maximum | D = 2,147,483,647 | Elaboration and the required 31-bit counter width. | No maximum-duration acquisition/qualification run. |
| PULSE composition | W = 8; S = 2; D = 3 | Independent channel/timer activity, simultaneous events, cancellation isolation, reset/disable. | Other channel counts are supported by generated RTL but not exhaustively instantiated by the regression. |
| Water-tank application | W = 8; D = 3; window = 64 cycles; tank step = 5 clocks; fill step = 10 units | Model feedback, noise, protection, manual recovery, reset, invalid thresholds, and response races. | D = 3 is 60 ns and the window is 1.28 us. These accelerated, unitless model settings are not field-calibrated timing or hydraulics. |

For the application timeout fixture, PULSE done registers at start + 64 cycles and the controller stops the pump at start + 65 cycles, or 1.30 us. For a persistent sensor captured at c0, qualification becomes visible at c(D+2); a synchronous controller consumes it on the following edge. Testbench checks preserve these separate latencies.

## 3. One-shot verification matrix

Bench: [pulse_timer_tb.sv](../tb/pulse_timer_tb.sv). Target: [pulse_timer.sv](../src/pulse_timer.sv). All rows are required for acceptance of the implemented baseline, including its adopted busy/cancel/enable conventions. Current final-run status for P-001…P-008: **PASS in both final runs; evidence in section 8**.

| ID | Bench label | Stimulus | Expected result |
| --- | --- | --- | --- |
| P-001 | T01 | Reset with competing controls; disabled start; start plus cancel while idle. | Reset clears state; disable/cancel inhibit start; busy and done stay low. |
| P-002 | T02 | Complete every 8-bit configuration; change bus after acceptance. | Start consumes no elapsed interval; done at e(max(1,N)); busy holds until then; done clears one edge later without restart. |
| P-003 | T03 | Exercise W = 1 alongside all reduced-width operations. | Both input values produce busy at start and done at e1; event clears normally. |
| P-004 | T04 | Start while busy and on expiry; change configuration; start immediately after expiry. | Active deadline remains captured; expiry-edge start ignored; next eligible edge captures a fresh interval. |
| P-005 | T05 | Hold start high through busy, expiry, and subsequent idle. | No active restart; a later idle edge accepts another interval. This checks documented behavior for a misused strobe, not a new handshake guarantee. |
| P-006 | T06 | Cancel/reset/disable during counting and at the final-count edge; compete with start; release abort. | Abort wins over expiry and start; no done, queued start, or pause/resume; held cancel inhibits requests. |
| P-007 | T07 | Load 32'hffff_ffff, advance once, then cancel. | Exact maximum captured, unsigned decrement, and cleared state. Full maximum completion is not claimed. |
| P-008 | T08 | Default-width zero and 1,000-cycle completion; load/decrement/cancel 250,000,000. | Zero normalizes; representative deadline exact; the illustrative 5 s configuration fits without overflow. Full 5 s completion is not claimed. |

## 4. Sensor qualification verification matrix

Bench: [pulse_debounce_tb.sv](../tb/pulse_debounce_tb.sv). Target: [pulse_debounce.sv](../src/pulse_debounce.sv). All rows are required baseline checks. Current final-run status for P-009…P-017: **PASS in both final runs; evidence in section 8**.

| ID | Bench label | Stimulus | Expected result |
| --- | --- | --- | --- |
| P-009 | D00 | Inspect elaborated count widths at D = 1, 4, 1,000,000, and INT_MAX. | Widths 1, 3, 20, and 31; inclusive storage and intermediate arithmetic do not overflow. |
| P-010 | D01 | Reset; enable with a persistent zero or one input. | Reset output is invalid; first fresh observation at a2; qualification only at a(2+D), including a zero-valued input. |
| P-011 | D02 | Persistent rising and falling changes after qualification. | Last output/validity remain until c(D+2); each direction receives D full intervals after synchronization. |
| P-012 | D03 | Positive pulses lasting 1…D captured samples, including return on the candidate expiry observation. | No positive acceptance; current mismatch wins over expiring old candidate. |
| P-013 | D04 | Negative pulse with return on its expiry observation. | Accepted one and validity persist; no false negative acceptance. |
| P-014 | D05 | Repeated alternating chatter; interrupted candidate; return and renewed candidate. | No spurious output; validity remains high; final candidate gets a fresh full interval. |
| P-015 | D06 | Reset/disable during VERIFYING and after a qualified value; change input while disabled; re-enable zero and one. | All local state clears; stale candidate cannot survive; synchronization readiness and qualification restart. |
| P-016 | D07 | D = 1 startup, falling change, one-sample glitch, disable/re-enable. | Two matching observations are required after acquisition; startup at a3, not a2; expiry-edge mismatch is rejected. |
| P-017 | D08 | Run all 1,000,000 default stability intervals with a persistent input. | No early validity; acceptance at a(1,000,002); accepted value remains stable. |

## 5. Composition verification matrix

Bench: [pulse_top_tb.sv](../tb/pulse_top_tb.sv). Target: [pulse_top.sv](../src/pulse_top.sv). All rows are required baseline checks. Current final-run status for P-018…P-024: **PASS in both final runs; evidence in section 8**.

| ID | Bench label | Stimulus | Expected result |
| --- | --- | --- | --- |
| P-018 | P01 | Both sensors initially zero following reset. | Both remain invalid until acquisition plus full qualification; top wiring adds no output stage. |
| P-019 | P02 | Run an 18-cycle window while channel 0 chatters and channel 1 changes persistently. | Channel 1 qualifies independently; channel 0 retains its accepted value; timer deadline remains exact despite noise/config changes. |
| P-020 | P03 | Cancel a live timer during a pending falling qualification. | Timer aborts without done; sensor candidate deadline and validity are unchanged. |
| P-021 | P04 | Align both sensor qualifications with a 5-cycle timer expiry. | Sensor outputs and done are all visible after the same edge; none is lost; done clears normally. |
| P-022 | P05 | Reset during an active timer and pending sensor changes; release with new input. | Whole block clears; no stale work; fresh complete startup acquisition required. |
| P-023 | P06 | Disable during active work; keep start asserted while disabled; re-enable. | Timer aborts and sensors invalidate; disabled starts ignored; fresh acquisition begins on re-enable. |
| P-024 | P07 | Continue enabled beyond the aborted operation's former deadline without a new start. | No resumed count, delayed done, or automatic timer restart. |

## 6. Application verification matrix

Bench: [water_tank_system_tb.sv](../tb/water_tank_system_tb.sv). Targets: [application controller](../src/application/water_tank_controller.sv), PULSE, and the simulation-only [tank](../tb/models/water_tank_model.sv), [pump](../tb/models/pump_model.sv), and [sensor](../tb/models/sensor_model.sv) models. A–E are required application scenarios; F/G additionally verify adopted APP-06/APP-07 decisions and must pass for this implemented demonstration. Current final-run status for P-025…P-031: **PASS in both final runs; evidence in section 8**.

| ID | Case | Stimulus | Expected result |
| --- | --- | --- | --- |
| P-025 | A | Source available; model feedback moves tank LOW → MID → FULL; later drain to MID. | Qualified LOW starts pump and timer on the same edge; response cancels monitoring; MID preserves active fill; FULL stops without fault; idle MID does not restart. Model level remains bounded. |
| P-026 | B1/B2 | Invert both modeled thresholds for D-1 captured samples on a full tank and during source-absent monitoring. | False LOW cannot start a full tank; false MID/FULL cannot cancel/stop monitoring; qualified values stay unchanged. |
| P-027 | C | Source unavailable at LOW; no response for the whole window. | Pump model runs but produces no flow; tank stays empty; done at start + N; pump stops and protection latches at start + N+1. |
| P-028 | D | Restore source and wait longer than a window while protected; then assert manual fault clear. | Restored source alone cannot retry; clear returns to IDLE; a later LOW edge starts a fresh operation and normal filling completes. |
| P-029 | E | Reset at startup, WAIT_RESPONSE, FILLING after MID response, and PROTECTED. | Pump/fault/PULSE state clears; fresh validity required; reset releases latch; resetting at MID returns to idle without starting a new fill. |
| P-030 | F | Schedule raw MID and, separately, FULL so qualification and done both register at eN. | Next controller edge observes both; response outranks timeout; MID continues filling and FULL stops; no dry-run latch. Raw-input scheduling uses no force or internal-state write. |
| P-031 | G | Qualify contradictory code 10 at startup and during WAIT_RESPONSE/FILLING; disable/re-enable during operation; disable while protected. | Contradiction inhibits/stops without latching dry-run; a pending window cancels; disable clears whole block/latch; re-enable repeats fresh qualification. |

These cases verify the APP-01…APP-08 demonstration assumptions. They do not establish the actual SENTINEL encoding, physical dry-run causation, safe pump timing, or protection against flow loss after the initial MID response. That later-loss behavior is outside this controller's stated scope.

## 7. Tool, diagnostic, review, and conditional checks

Supplemental probes below are distinct from the four committed functional benches. Record their actual commands, expected diagnostics, exit statuses, and evidence location separately. A negative test passes only by producing the intended failure; a nonzero exit alone does not prove the correct diagnostic.

| ID | Priority | Check | Acceptance / evidence scope | Current record |
| --- | --- | --- | --- | --- |
| P-032 | Required | ModelSim runner success/failure handling and timeout safeguards. | Successful bench yields marker one and process zero; a deliberate pre-success fatal yields no success marker and nonzero exit. Inspect the log gate and watchdog paths. Actual wall-clock-timeout injection is a separate check if run. | PASS for executed normal-finish and intentional-fatal probes: exits 0 and 4 respectively. Watchdog/log/timeout paths reviewed; no wall-clock-timeout injection claimed. |
| P-033 | Recommended diagnostic verification | Invalid parameter and unknown control probes. | Expect specific fatal for W = 0, S = 0, D = 0, D = -1; separately timer reset=X, timer enable=X, debounce reset=X, debounce enable=X. No invalid-input hardware recovery is implied. | PASS for all eight temporary probes: expected specific fatal observed. Not added to the committed functional suite. |
| P-034 | Required | Static RTL/clock-domain review and Quartus analysis/synthesis for core and application tops. | Inspect signedness, widths, register ownership, latch/feedback inference, reset, two-stage acquisition, warnings, and available resource reports. Exclude model/testbench sources. | Structural review complete. Both synthesis tops PASS with 0 errors and one reviewed warning 20028 each; see [synthesis check](SYNTHESIS_CHECK.md). No physical implementation/CDC signoff. |
| P-035 | Required | Documentation, traceability, waveform evidence, and integration assumptions. | Match actual source/test interfaces to requirements, timing, architecture, FSM, and APP decisions. Check diagram/trace explanations against actual wave data; retain limitations and open team questions. | See [waveform observations](WAVEFORM_OBSERVATIONS.md), [known issues](KNOWN_ISSUES.md), and [final report](FINAL_REPORT.md). Final delivery review is tracked there; no blanket completed-review claim is made here. |
| P-036 | Required | Repository/delivery review. | Logical commits, existing work preserved, generated tool outputs isolated, reproducible scripts and documented workflow; initial review stop followed by the user's continuation. | Committed source was validated in a fresh local clone, including a path containing spaces. Final Git/status evidence is tracked in [final report](FINAL_REPORT.md). |
| P-037 | Optional / conditional F-11 | Periodic event first edge, spacing, disable/re-enable, and period capture. | Applicable only after an identified consumer adopts a periodic implementation and contract. | **N/A — excluded from the implemented baseline.** No periodic PASS claimed. |

Temporary diagnostic probes are not portable regression assets unless their sources/scripts are deliberately added later. A final report may cite their observed results, but must distinguish those supplemental observations from `sim/run.ps1 -Test all`. Unknown sampled sensor/configuration checks and illegal-state recovery are not exhaustively fault-injected by the four benches.

## 8. Execution and evidence handling

Run the committed suite from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File sim/run.ps1 -Test all
```

Use `-Test pulse_timer_tb`, `pulse_debounce_tb`, `pulse_top_tb`, or `water_tank_system_tb` for a selected bench. The runner resolves ModelSim through PATH or its `-ModelSimBin` option and creates an isolated directory below `build/modelsim`. It creates local library mappings and leaves global editor/tool settings alone. [compile.do](../sim/compile.do) defines compilation; [simulate.do](../sim/simulate.do) controls execution; [wave.do](../sim/wave.do) provides the wave setup.

Expected run artifacts include a compilation transcript, individual test transcripts/WLF files, `results.json`, and the application's `water_tank_system.vcd`. Record the actual timestamped run directory and source revision in final evidence. Do not replace testbench outcomes with a screenshot alone.

ModelSim-Altera 10.1d invokes ONBREAK on ordinary `$finish` when `-onfinish stop` is selected. The script must resume Tcl after that break and inspect `test_passed`; treating every break as failure rejects legitimate completion. Conversely, accepting `$finish` alone can conceal a failed check. Keep the explicit marker and transcript-error gates.

| Final evidence item | Acceptance | Current result |
| --- | --- | --- |
| Compilation of all committed sources/benches | No compile/elaboration errors; relevant warnings reviewed. | PASS in both workspace and clean-clone regressions. |
| `pulse_timer_tb` | P-001…P-008 pass with stated duration limits. | PASS; 100,985 checks; finish at 684,131 ns. |
| `pulse_debounce_tb` | P-009…P-017 pass, including full default debounce. | PASS; 1,000,277 checks; finish at 20,004,271 ns. |
| `pulse_top_tb` | P-018…P-024 pass. | PASS; finish at 1,931 ns. No aggregate check count is emitted by this bench. |
| `water_tank_system_tb` | P-025…P-031 / A–G pass. | PASS; 715 checks, 684 cycles; finish at 13,671 ns. |
| Runner and negative diagnostics | Actual expected failure/success evidence matches P-032/P-033. | Executed probes PASS: intentional fatal exit 4, normal finish exit 0, eight specific parameter/control fatals observed. |
| Core/application Quartus analysis | Tool output and warning/resource interpretation recorded under P-034. | Both tops PASS; 0 errors and warning 20028 only for each. Structural review complete; [synthesis details](SYNTHESIS_CHECK.md). |
| Waveform and delivery review | P-035/P-036 evidence agrees with final source and tests. | Evidence in [waveform observations](WAVEFORM_OBSERVATIONS.md); final delivery disposition in [final report](FINAL_REPORT.md). |

The reproduced RTL/test/script source revision is `dda71462f805f3c14a57512ef573cbcc6aa8d583`. The workspace regression artifacts are in `build/modelsim/run-20260910-023217-006`. A fresh local clone at `C:\Users\HP\AppData\Local\Temp\pulse clean validation 98e11292f0414bfcafcaec56046fc6c3` reproduced all four PASS results in `build/modelsim/run-20260910-023634-832` and both synthesis tops in `build/quartus/run-20260910-023715-443`, relative to that clone. Documentation/evidence updates after this source revision do not represent a different tested RTL implementation.

The clean synthesis map reports estimate 224 logic elements / 92 registers for `pulse_top` and 241 logic elements / 96 registers for the application. These report estimates differ from the tool's informational logic-cell fields of 225 and 242; do not interchange the two metrics. Neither is a fitted physical utilization/timing result. Warning 20028 and the detailed scope are explained in [SYNTHESIS_CHECK.md](SYNTHESIS_CHECK.md).

Supplemental parameter/control sources `invalid_parameters_tb.sv` and `unknown_controls_tb.sv`, plus their per-case transcripts, were run under `C:\Users\HP\AppData\Local\Temp\pulse_core_units_47274e510123475daa7c861cd2e16cf8`. Their temporary driver intentionally exits 7 after collecting the expected fatal, so acceptance uses the specific diagnostic as well as termination. The normal-finish/intentional-fatal runner experiment is under `C:\Users\HP\AppData\Local\Temp\pulse-application-527a4e35832b46e18e6df956904a340b`. These paths record local supplemental provenance, not build dependencies or committed regression content. Retained limitations are collected in [KNOWN_ISSUES.md](KNOWN_ISSUES.md).

## 9. Exit criteria and explicit exclusions

Accept the digital baseline when all applicable implemented checks pass, required reviews are complete, material warnings are explained, and a final report names the source/run evidence and remaining integration questions. A failed check requires a cause/fix and relevant rerun; an unexecuted check remains unverified. No aggregate coverage percentage is inferred from check counts or this matrix.

Physical metastability resolution, placement/routing, pin/electrical behavior, oscillator tolerance, hydraulic response, sensor bounce calibration, and actual pump safety remain outside the evidence. The 5 s and full maximum timer completions, maximum debounce duration, arbitrary parameter combinations, and exhaustive state/control fault injection are not established by this suite. The optional periodic function remains N/A until its conditional requirement is adopted. The PASS results above do not resolve Q-01…Q-08 or finalize external interfaces.
