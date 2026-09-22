# PULSE verification plan

Prepared: 2026-09-10; updated: 2026-09-22 for OSC-CONTRACT-1. Status: **Seven-bench regression and structural RTL/synthesis checks complete; current source/release evidence is tracked in the [oscillator completion report](OSCILLATOR_COMPLETION.md).** The working digital contract is provisional for external integration. Recorded PASS results below apply only to the stated checks and limits.

Implementation language: Verilog HDL. All production sources, models, and benches use `.v` files; ModelSim compilation explicitly selects Verilog-2001 with `vlog -vlog01compat`. The [conversion report](VERILOG_CONVERSION.md) retains historical language-conversion evidence; the [oscillator completion report](OSCILLATOR_COMPLETION.md) records current executable revision and clean-checkout validation.

## 1. Scope and acceptance method

Verify the independent one-shot, individual sensor qualifier, recurring clock-enable generator, their composition, and the provisional GUARDIAN demonstration. Periodic behavior follows [OSC-CONTRACT-1](OSCILLATOR_CONTRACT.md). The acceptance oracle is the edge behavior in [timing](PULSE_TIMING_SPEC.md), [state machines](PULSE_STATE_MACHINES.md), and [water-tank behavior](WATER_TANK_BEHAVIOR.md). [Traceability](TRACEABILITY_MATRIX.md) maps every functional and non-functional requirement to these checks or to review/delivery evidence.

All functional fixtures use a 20 ns clock period, corresponding to an illustrative 50 MHz. Stimulus is normally driven on falling edges; outputs are checked after rising-edge registered updates. Timers are judged against elapsed edge numbers, and debounce is judged against the first raw capture plus the documented acquisition/qualification delay. Synthesis-excluded procedural checks additionally inspect internal invariants and print `FAIL` followed by `$stop` on a violation. These supplement the public-output checks.

Each committed bench has a `test_passed` marker initialized to zero, procedural self-checks that print `FAIL` and call `$stop`, a bounded simulation watchdog, and a completion message. It sets the marker only after its required checks. A successful run requires successful compilation/elaboration, normal completion, marker one, and no native simulator error/fatal or Verilog `FAIL` diagnostic. The host runner also imposes a wall-clock timeout. Packed 256-byte task arguments preserve all diagnostic text without a language-specific string type.

The labels P-001 through P-046 below are document-level verification IDs. T01–T08, D00–D08, P01–P11, O01–O06, C01–C07, and A–G are labels in the corresponding benches. In particular, top-level bench label P01 is distinct from document ID P-001.

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
| PULSE composition | W = 8; S = 2; D = 3; periodic R = 5 | Independent channel/timer/periodic activity, simultaneous events, cancellation isolation, reset/disable, local periodic restart. | Other channel counts are supported by generated RTL but not exhaustively instantiated by the regression. |
| Water-tank application | W = 8; D = 3; window = 64 cycles; tank step = 5 clocks; fill step = 10 units | Model feedback, noise, protection, manual recovery, reset, invalid thresholds, and response races. | D = 3 is 60 ns and the window is 1.28 us. These accelerated, unitless model settings are not field-calibrated timing or hydraulics. |
| Periodic reduced/minimum width | R = 4, all settings 0…15; R = 1, settings 0/1 | At least three repeated periods, first-event latency, consecutive P = 1 events, live configuration changes across reloads, clearing/restart, synchronous consumer. | Exhaustive over the reduced configuration domain, not all input histories. |
| Periodic default width | R = 32; periods 3, 4, 257, 1,000; maximum unsigned count | Three full periods for each representative value; maximum has 32 quiet observed edges followed by abort/restart. | No full 4,294,967,295-cycle expiry; bounded output observation alone does not prove all high bits of arbitrary parameterizations. |
| Periodic checker self-test | Predetermined sample schedules; no generator DUT | Known-good P = 0/1/2/3/4 traces and nine intentionally bad samples. | Validates the checker on named faults, not formal completeness. |

For the application timeout fixture, PULSE done registers at start + 64 cycles and the controller stops the pump at start + 65 cycles, or 1.30 us. For a persistent sensor captured at c0, qualification becomes visible at c(D+2); a synchronous controller consumes it on the following edge. Testbench checks preserve these separate latencies.

## 3. One-shot verification matrix

Bench: [pulse_timer_tb.v](../tb/pulse_timer_tb.v). Target: [pulse_timer.v](../src/pulse_timer.v). All rows are required for acceptance of the implemented baseline, including its adopted busy/cancel/enable conventions. Current final-run status for P-001…P-008: **PASS in the current seven-bench regression; evidence in section 8**.

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

Bench: [pulse_debounce_tb.v](../tb/pulse_debounce_tb.v). Target: [pulse_debounce.v](../src/pulse_debounce.v). All rows are required baseline checks. Current final-run status for P-009…P-017: **PASS in the current seven-bench regression; evidence in section 8**.

| ID | Bench label | Stimulus | Expected result |
| --- | --- | --- | --- |
| P-009 | D00 | Inspect actual elaborated count widths at D = 1, 4, 1,000,000, and INT_MAX by concatenating a leading sentinel and shifting away the expected width. | Widths 1, 3, 20, and 31; sentinel must equal one after the shift, including when register contents are initially unknown. Inclusive storage and intermediate arithmetic do not overflow. |
| P-010 | D01 | Reset; enable with a persistent zero or one input. | Reset output is invalid; first fresh observation at a2; qualification only at a(2+D), including a zero-valued input. |
| P-011 | D02 | Persistent rising and falling changes after qualification. | Last output/validity remain until c(D+2); each direction receives D full intervals after synchronization. |
| P-012 | D03 | Positive pulses lasting 1…D captured samples, including return on the candidate expiry observation. | No positive acceptance; current mismatch wins over expiring old candidate. |
| P-013 | D04 | Negative pulse with return on its expiry observation. | Accepted one and validity persist; no false negative acceptance. |
| P-014 | D05 | Repeated alternating chatter; interrupted candidate; return and renewed candidate. | No spurious output; validity remains high; final candidate gets a fresh full interval. |
| P-015 | D06 | Reset/disable during VERIFYING and after a qualified value; change input while disabled; re-enable zero and one. | All local state clears; stale candidate cannot survive; synchronization readiness and qualification restart. |
| P-016 | D07 | D = 1 startup, falling change, one-sample glitch, disable/re-enable. | Two matching observations are required after acquisition; startup at a3, not a2; expiry-edge mismatch is rejected. |
| P-017 | D08 | Run all 1,000,000 default stability intervals with a persistent input. | No early validity; acceptance at a(1,000,002); accepted value remains stable. |

## 5. Composition verification matrix

Bench: [pulse_top_tb.v](../tb/pulse_top_tb.v). Target: [pulse_top.v](../src/pulse_top.v). All rows are required baseline checks. Current final-run status for P-018…P-024: **PASS in the current seven-bench regression; evidence in section 8**.

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

Bench: [water_tank_system_tb.v](../tb/water_tank_system_tb.v). Targets: [application controller](../src/application/water_tank_controller.v), PULSE, and the simulation-only [tank](../tb/models/water_tank_model.v), [pump](../tb/models/pump_model.v), and [sensor](../tb/models/sensor_model.v) models. A–E are required application scenarios; F/G additionally verify adopted APP-06/APP-07 decisions and must pass for this implemented demonstration. Current final-run status for P-025…P-031: **PASS in the current seven-bench regression; evidence in section 8**.

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

Supplemental TEMP probes below are distinct from the seven runnable benches; the committed periodic checker self-test separately includes controlled negative schedules. Record their actual commands, expected diagnostics, exit statuses, and evidence location separately. A negative test passes only by producing the intended failure; a nonzero exit alone does not prove the correct diagnostic.

| ID | Priority | Check | Acceptance / evidence scope | Current record |
| --- | --- | --- | --- | --- |
| P-032 | Required | ModelSim runner success/failure handling and timeout safeguards. | Successful bench yields marker one and process zero; a deliberate pre-success `FAIL`/`$stop` yields no success marker and nonzero exit. Inspect the log gate and watchdog paths. Actual wall-clock-timeout injection is a separate check if run. | PASS for executed normal-finish and intentional-check-failure probes: exits 0 and 4 respectively. Watchdog/log/timeout paths reviewed; no wall-clock-timeout injection claimed. |
| P-033 | Recommended diagnostic verification | Invalid parameter and unknown control probes. | Original cases: W = 0, S = 0, D = 0, D = -1 and timer/debounce reset=X or enable=X. Periodic cases: R = 0, each reset/global/local enable=X, and unknown accepted configuration. Expect a specific `FAIL` diagnostic and `$stop`; no invalid-input hardware recovery is implied. | Eight original probes passed at conversion; all five added periodic probes passed on 2026-09-22. These TEMP probes are separate from the runnable suite. |
| P-034 | Required | Static RTL/clock-domain review and Quartus analysis/synthesis for core and application tops. | Inspect signedness, widths, register ownership, latch/feedback inference, reset, two-stage acquisition, warnings, and available resource reports. Exclude model/testbench sources. | Structural review complete. Both synthesis tops PASS with 0 errors and one reviewed warning 20028 each; see [synthesis check](SYNTHESIS_CHECK.md). No physical implementation/CDC signoff. |
| P-035 | Required | Documentation, traceability, waveform evidence, and integration assumptions. | Match actual source/test interfaces to requirements, timing, architecture, FSM, and APP decisions. Check diagram/trace explanations against actual wave data; retain limitations and open team questions. | See [waveform observations](WAVEFORM_OBSERVATIONS.md), [known issues](KNOWN_ISSUES.md), and [final report](FINAL_REPORT.md). Final delivery review is tracked there; no blanket completed-review claim is made here. |
| P-036 | Required | Repository/delivery review. | Logical commits, preservation, generated outputs isolated, reproducible scripts, current oscillator implementation and evidence. | Current workspace validation passes; current revision, clean-checkout and delivery review are recorded in [OSCILLATOR_COMPLETION.md](OSCILLATOR_COMPLETION.md). Historical conversion clone evidence remains explicitly dated in section 8.2. |
| P-037 | F-11 adopted for current scope | Periodic event first edge, spacing, disable/re-enable, captured period, consumer semantics and composition. | OSC-CONTRACT-1; aggregate acceptance requires P-038…P-046 and periodic inclusion in P-032/P-034/P-036. | PASS for the observed standalone/checker/concurrency/smoke regression and both synthesis tops. External consumer and supervisor interpretation remain provisional. |

Temporary diagnostic probes are not portable regression assets unless their sources/scripts are deliberately added later. A final report may cite their observed results, but must distinguish those supplemental observations from `sim/run.ps1 -Test all`. The deliberately invalid W = 0 fixture also produces ModelSim warning `vsim-8602` for zero replication before its parameter guard stops; this warning does not occur for legal configurations. Unknown sampled sensor/configuration checks and illegal-state recovery are not exhaustively fault-injected by the runnable benches.

### 7.1 Periodic verification matrix

The [independent unit bench](../tb/pulse_periodic_tb.v) checks edge-relative deadlines and a separate synchronous consumer. The [checker](../tb/pulse_periodic_checker.v) derives expected events from elapsed timestamps modulo the period captured at p0, without reading or mirroring the DUT countdown. It samples registered output after nonblocking updates. `error_count` is cumulative across functional reset; `REPORT_ERRORS=1` prints `FAIL` and stops, while zero supports expected-error checker self-tests.

| ID | Bench / labels | Stimulus | Established result |
| --- | --- | --- | --- |
| P-038 | Unit O01 | Reset with competing enables; global and local enables separately absent. | No capture/event until both enables are sampled high with reset low. |
| P-039 | Unit O02 | All reduced-width settings 0…15 for at least three periods; change live bus every edge, including reloads. | Capture edge remains low; exact pP/p2P/p3P deadlines; one high interval for P > 1; zero/P = 1 consecutive events; consumer acts one edge after registered events. |
| P-040 | Unit O03 | Reset/global/local disable at e2 and expiry e5 for captured P = 5; hold clearing; restart with P = 3 while changing live bus to 10. | Every clear wins expiry and discards phase; restart captures new period with no p0 event; later reloads retain captured 3. |
| P-041 | Unit O04 | R = 1 with both representable values; consecutive events; local disable/re-enable. | Both normalize to P = 1; fresh capture precedes repeated high cycles; clear drops output. |
| P-042 | Unit O05 | R = 32 with P = 3, 4, 257, 1,000, completing at least three periods each. | Odd/even and above-eight-bit periods meet every expected deadline; active live bus does not change spacing. |
| P-043 | Unit O06 | R = 32 maximum, 32 observed active edges with live bus zero, local abort, restart with P = 2. | No premature event in observed interval; abort clears; new period repeats correctly. No maximum-duration completion claim. |
| P-044 | Checker C01…C07 | No DUT; predetermined good sequences plus early, missed/late, extended-width, reset/global/local/capture-edge, and unknown-output violations. | Exactly nine bad samples detected; good samples produce no false positive. Expected violations remain quiet; a checker mismatch still fails the bench. |
| P-045 | Top P08…P11 | Concurrent periodic events, noisy channels, busy starts/cancel and timer completion; local restart; global disable/reset on expiry; zero minimum. | Periodic phase ignores unrelated controls; local clear preserves timer/sensor deadlines; simultaneous tick/done survive; shared clear wins and requires fresh startup. |
| P-046 | Developer smoke | P = 3 repeated operation with changed live bus; P = 2 restart; reset/global/local disable including expiry; zero/P = 1. | 35 developer checks pass independently of the unit suite/checker. |

The periodic unit's `+PULSE_INJECT_FAILURE` inserts an intentional failing check immediately before success. This supplements P-032 and proves the actual bench/runner path rejects an incomplete run; normal regression does not enable it. The water-tank adapter ties periodic enable low and supplies zero configuration, so periodic integration does not invent a pump-control consumer.

## 8. Execution and evidence handling

Run the committed suite from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File sim/run.ps1 -Test all
```

Use `-Test` with any bench in the current results table, including `pulse_periodic_smoke_tb`, `pulse_periodic_checker_tb`, and `pulse_periodic_tb`, for a selected run. `-Test pulse_periodic_tb -InjectFailure` deliberately stops before success and is expected to fail; its ModelSim process returns 4. The runner resolves ModelSim through PATH or its `-ModelSimBin` option and creates an isolated directory below `build/modelsim`. It creates local library mappings and leaves global editor/tool settings alone. [compile.do](../sim/compile.do) defines compilation; [simulate.do](../sim/simulate.do) controls execution; [wave.do](../sim/wave.do) provides the wave setup.

Expected run artifacts include a compilation transcript, individual test transcripts/WLF files, `results.json`, and VCDs for application, periodic smoke/unit, and top-level traces. Record the actual timestamped run directory and source revision in final evidence. Do not replace testbench outcomes with a screenshot alone.

ModelSim-Altera 10.1d invokes ONBREAK on ordinary `$finish` when `-onfinish stop` is selected. The script must resume Tcl after that break and inspect `test_passed`; treating every break as failure rejects legitimate completion. Conversely, accepting `$finish` alone can conceal a failed check. Keep the explicit marker and transcript-error gates.

### 8.1 Current oscillator evidence (2026-09-22)

All seven benches passed in clean workspace run `build/modelsim/run-20260922-103440-575`; each transcript and `results.json` was inspected. ModelSim-Altera 10.1d compiled all 16 `.v` files with `vlog -vlog01compat`; there were no compiler/simulator errors or warnings in this normal run.

| Final evidence item | Acceptance | Current result |
| --- | --- | --- |
| Compilation of all current sources/benches | All 16 `.v` files compile in Verilog-2001 mode; no compile/elaboration errors; relevant warnings reviewed. | PASS in current clean workspace run; current committed-revision/clone evidence is in [completion report](OSCILLATOR_COMPLETION.md). |
| `pulse_timer_tb` | P-001…P-008 pass with stated duration limits. | PASS; 100,985 checks; finish at 684,131 ns. |
| `pulse_debounce_tb` | P-009…P-017 pass, including full default debounce. | PASS; 1,000,277 checks; finish at 20,004,271 ns. |
| `pulse_top_tb` | Original P-018…P-024 and added P-045 pass. | PASS; cases P01…P11 finish at 2,931 ns. No aggregate check count is emitted; the historical P01…P07-only run finished at 1,931 ns. |
| `water_tank_system_tb` | P-025…P-031 / A–G pass. | PASS; 715 checks, 684 cycles; finish at 13,671 ns. |
| `pulse_periodic_smoke_tb` | P-046 passes independently. | PASS; 35 checks / 35 cycles; finish at 711 ns. |
| `pulse_periodic_checker_tb` | P-044 detects the predetermined defects without false positives. | PASS; 99 checks / 49 cycles; nine expected erroneous samples; finish at 992 ns. |
| `pulse_periodic_tb` | P-038…P-043 plus synchronous consumer pass. | PASS; 9,330 checks / 4,396 cycles; finish at 87,932 ns. |
| Runner and negative diagnostics | Actual expected failure/success evidence matches P-032/P-033. | Normal finish exits 0; injected actual periodic bench stops with marker zero and ModelSim exit 4; five added periodic diagnostic probes stop with their expected messages. Eight original conversion probes remain historical evidence. |
| Core/application Quartus analysis | Tool output and warning/resource interpretation recorded under P-034. | Both tops PASS; 0 errors and warning 20028 only for each. Structural review complete; [synthesis details](SYNTHESIS_CHECK.md). |
| Waveform and delivery review | P-035/P-036 evidence agrees with final source and tests. | Evidence in [waveform observations](WAVEFORM_OBSERVATIONS.md); final delivery disposition in [final report](FINAL_REPORT.md). |

Current synthesis artifacts are in `build/quartus/run-20260922-102633-279`: estimated core resources are 385 logic elements / 158 registers with periodic ports exposed, and application resources remain 241 logic elements / 96 registers because the periodic function is disabled there. Both tops report only license warning 20028. These are analysis/synthesis estimates, not fitted utilization or physical timing signoff. Current executable revision, clean-checkout reproduction, measured waveform review, and final handoff are recorded in [OSCILLATOR_COMPLETION.md](OSCILLATOR_COMPLETION.md).

The independent periodic unit and checker initially passed in a fresh TEMP work library at `C:\Users\HP\AppData\Local\Temp\pulse-periodic-independent-bea0899d89d8490f8fcdec5fb55b703c`, using the installed `vlog -vlog01compat` and per-bench `vsim -novopt -onfinish stop` macros. Counts/times match the current repository run. Its `+PULSE_INJECT_FAILURE` run printed the intended failure at cycle 4,396, left `test_passed=0`, and returned exit 4. The repository's equivalent `sim/run.ps1 -Test pulse_periodic_tb -InjectFailure` probe is recorded under `build/modelsim/run-20260922-102632-929`; the host wrapper rejects the ModelSim failure.

The five added P-033 TEMP diagnostic sources, macros, `results.json`, and transcripts are under `C:\Users\HP\AppData\Local\Temp\pulse-periodic-diagnostics-adefaf61ef72462ba31838e8896f1749`. All produced the specific expected `FAIL` and stopped with `reached_end=0`; the diagnostic macros then returned zero after confirming the stop. `PERIOD_WIDTH=0` additionally produces `vsim-8602` for zero replication before its positivity guard stops. That warning occurs only in this unsupported-width negative fixture. The three unknown control probes and unknown accepted-configuration probe emit no such warning.

### 8.2 Historical conversion evidence (2026-09-10)

The following records validate the pre-periodic revision and are retained as history; current oscillator evidence is in section 8.1. The Verilog conversion workspace regression artifacts are in `build/modelsim/run-20260910-065458-111`; clean core/application synthesis artifacts are in `build/quartus/run-20260910-065547-884`. A separately created TEMP library at `C:\Users\HP\AppData\Local\Temp\pulse-verilog-bench-d98df18a568e4174b9517b863f0ba81a` compiled all 11 `.v` files using the installed ModelSim-Altera 10.1d `vlog -vlog01compat` and reproduced all four PASS results with exactly the original counts and finish times. These conversion runs replace the earlier implementation's evidence; the executable source revision and final fresh-checkout record are in [VERILOG_CONVERSION.md](VERILOG_CONVERSION.md).

Executable revision `c9c9016d3703e60e37317406c354b07f4bde38f0` was separately cloned with `git clone --no-hardlinks` and checked out detached at `C:\Users\HP\AppData\Local\Temp\pulse Verilog clean validation 08e9035effda424d9f74baa2c85da0b3`. No build directory existed before execution. `sim/run.ps1 -Test all` reproduced all four PASS results, counts, and finish times in `build/modelsim/run-20260910-070543-875`; `synth/run.ps1 -Top all -QuartusBin C:/altera/13.0sp1/quartus/bin64` reproduced both successful synthesis results in `build/quartus/run-20260910-070543-799`. These paths are relative to the clone. No compiler/simulator warnings occurred, and each synthesis top reported only warning 20028. All 11 `pulse.teroshdl.yml` entries are relative `.v` paths with `file_type=verilogSource`; every source and the top-level path resolve in the clone. Its working tree remained clean after both runs.

The historical conversion synthesis map reports estimate 224 logic elements / 92 registers for `pulse_top` and 241 logic elements / 96 registers for the application. These report estimates differ from the tool's informational logic-cell fields of 225 and 242; do not interchange the two metrics. Neither is a fitted physical utilization/timing result. Warning 20028 and the detailed scope are explained in [SYNTHESIS_CHECK.md](SYNTHESIS_CHECK.md).

Supplemental Verilog drivers and transcripts are under `C:\Users\HP\AppData\Local\Temp\pulse-verilog-diagnostics-3b18d728f1b04b5583b11da343865f63`. `diagnostics.v` covers the eight P-033 cases. Commands `vlog -vlog01compat -work work` and `vsim -c -do diag_W0.do` compile/run the corresponding sources and per-case macros. Every case produced its specific `FAIL` diagnostic and stopped with `reached_end=0`; the TEMP macros then deliberately returned zero after checking that premature stop. A TEMP application-bench copy inserted `require_true(1'b0, ...)` immediately before setting `test_passed`. The unmodified repository `sim/simulate.do`, selected with `PULSE_TESTBENCH=water_tank_system_tb`, returned exit 4 at cycle 684 with `test_passed=0` and no success marker. ModelSim's `-l` transcript omits the Tcl stderr line, so acceptance uses the logged failing check, observed marker, and actual process exit together.

An additional TEMP `.v` source containing a `logic` declaration was rejected by `vlog -vlog01compat -work work invalid_systemverilog.v` with a syntax error and exit 2. This is a compiler-mode guard for the language conversion, not a functional design test. TEMP paths above record local supplemental provenance, not build dependencies or committed regression content. Retained limitations are collected in [KNOWN_ISSUES.md](KNOWN_ISSUES.md).

## 9. Exit criteria and explicit exclusions

Accept the digital baseline when all applicable implemented checks pass, required reviews are complete, material warnings are explained, and a final report names the source/run evidence and remaining integration questions. A failed check requires a cause/fix and relevant rerun; an unexecuted check remains unverified. No aggregate coverage percentage is inferred from check counts or this matrix.

Physical metastability resolution, placement/routing, pin/electrical behavior, oscillator tolerance, hydraulic response, sensor bounce calibration, and actual pump safety remain outside the evidence. The 5 s and full maximum timer completions, maximum debounce duration, arbitrary parameter combinations, and exhaustive state/control fault injection are not established by this suite. F-11 is adopted for OSC-CONTRACT-1. Full 32-bit maximum periodic completion, every possible width/period/control sequence, and physical waveform behavior are not established by the bounded digital tests. The PASS results above do not resolve Q-01…Q-08 or finalize external interfaces.
