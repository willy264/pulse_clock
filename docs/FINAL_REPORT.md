# PULSE final software-baseline report

Date: 2026-09-10. Status: **Implemented and verified digital baseline; external integration and physical assumptions remain provisional.** This report covers software/RTL/simulation and synthesis-oriented analysis, not physical implementation.

Executable source, testbenches, and tool scripts were validated at Git revision `c9c9016d3703e60e37317406c354b07f4bde38f0`. Subsequent delivery changes document those results and add review artifacts; they do not change the tested HDL or runner behavior.

Implementation language: Verilog HDL (Verilog-2001). The [conversion report](VERILOG_CONVERSION.md) records all 11 reviewed source conversions, current clean-build evidence, compatibility details, and the exact project structure. No new features were added during this correction.

## 1. Project overview

PULSE is the team's reusable Timer / Oscillator building block for the Micro2Nano Water Tank Level & Dry-Run Protection Controller. The repository began empty. The requested initial four-document stage stopped for review; the user's subsequent instruction to continue led to internally reviewed architecture/FSM design, RTL, verification, application integration, and the evidence recorded here.

## 2. Application problem

Noisy level inputs can produce false transitions, and a pump can remain commanded on without an expected level response. The demonstration therefore qualifies sensor observations and measures an explicit initial-response interval. It is a digital functional example, not a calibrated hydraulic model or definitive dry-run diagnosis.

## 3. PULSE's role

PULSE synchronizes/qualifies independent Boolean sensor inputs and supplies a reusable one-shot window with start, cancellation, busy, and elapsed-event status. Sensor chatter does not restart that window. A separate controller interprets the result and owns the pump/fault/manual-recovery behavior.

## 4. Requirements

[Requirements](PULSE_REQUIREMENTS.md) distinguish explicit/derived requirements from recommended controls, optional periodic behavior, and numerical assumptions. Timer, debounce, concurrent protection timing, deterministic synthesizable RTL, and self-checking verification are implemented. Periodic generation is intentionally excluded because no consumer is identified. Q-01…Q-08 remain open for real team integration; this does not invalidate the clearly labeled provisional demonstration.

## 5. Architecture

Three core modules share one clock: `pulse_timer`, one `pulse_debounce` per sensor, and the direct-wiring `pulse_top`. Downcounters have independent ownership. There is no separate counter wrapper, generated clock, PLL, bus, CPU, or vendor IP. [Architecture](PULSE_ARCHITECTURE.md) and [state machines](PULSE_STATE_MACHINES.md) define data/control/reset/configuration flow and edge behavior.

## 6. RTL implementation

The four files under `src` contain synthesizable Verilog HDL, including the provisional `water_tank_controller`. Registers have one sequential owner; combinational control has defaults; arithmetic counts are unsigned and sized. Procedural invariant checks and parameter diagnostics are inside synthesis-excluded regions. Testbench clock generation, stimulus timing, and models are separated under `tb` and excluded from synthesis.

## 7. Timing design

The illustrative clock is 50 MHz/20 ns. A start at e0 with N > 0 expires at eN, with zero normalized to one cycle. Configuration is captured once. Reset, disable, and cancel outrank expiry; starts while busy, including expiry-edge starts, are ignored. The 32-bit nominal maximum is 85.8993459 s. Physical accuracy depends on the actual clock, whose tolerance is not specified. [Timing](PULSE_TIMING_SPEC.md) records conversions and full boundary rules.

## 8. Debounce implementation

Each channel has two synchronization stages and a two-stage readiness pipeline. First fresh observation is a2 after first enabled capture a0; a stable candidate qualifies at a(2+D). A mismatch at expiration restarts the interval. Initial zero outputs remain invalid until fully qualified. Later validity stays high while the last accepted reading is retained through noise. The default D = 1,000,000 interval was simulated to completion; analog glitch rejection and metastability performance are not inferred from that digital result.

## 9. Dry-run timing implementation

The application adapter interprets `{full, above_low}` as LOW/MID/FULL and starts pump and window together at qualified LOW. Qualified MID confirms initial response and cancels the timer; FULL stops filling. Absent response at expiry latches suspected dry-run and stops the pump on the next controller observation edge. A manual clear or reset releases the latch. Simultaneous qualified response and done are resolved in favor of response. All of these are explicit APP assumptions in [water-tank behavior](WATER_TANK_BEHAVIOR.md), not another team's finalized policy.

## 10. Simulation methodology

ModelSim-Altera Starter 10.1d compiled all production sources, three digital models, and four testbenches with `vlog -vlog01compat`. The runner uses a fresh local `modelsim.ini`/work library, one simulation process per bench, bounded watchdogs, process timeout, explicit success flags/markers, transcript diagnostic checks, WLF capture, and application VCD capture.

Checks use observable clock deadlines and qualified outputs, plus selected internal invariants/width inspections. The timer tests all 256 configurations of an 8-bit timer, including zero, to exact completion. Application tests use accelerated D = 3 and N = 64; they do not pretend those are the physical 20 ms/5 s values. No result is inferred solely from compilation.

## 11. Verification results and reproducibility

All four converted benches passed the fresh repository build with the same check counts and finish times as the preceding baseline. Independent temporary-library runs and a fresh tracked clone also passed, with no reused build artifacts. Current clean-checkout provenance is recorded in [VERILOG_CONVERSION.md](VERILOG_CONVERSION.md).

| Bench | Observed result | Checks reported by bench | Finish time |
| --- | --- | --- | --- |
| `pulse_timer_tb` | PASS | 100,985 | 684,131 ns |
| `pulse_debounce_tb` | PASS | 1,000,277 | 20,004,271 ns |
| `pulse_top_tb` | PASS | No numerical check count emitted; named P01–P07 scenarios pass | 1,931 ns |
| `water_tank_system_tb` | PASS | 715 checks, 684 sampled cycles; A–G scenarios | 13,671 ns |

Check totals are execution counts, not a coverage percentage or proof of exhaustive state-space verification. The plan and [traceability matrix](TRACEABILITY_MATRIX.md) map specific requirements to these cases.

Documentation review passed for all 18 Markdown documents and 164 local links, table columns, code fences, UTF-8/newline integrity, current source references, language declarations, evidence, and compatibility settings. The measured timing plot was visually inspected in the original baseline and its source events exactly match the converted run. The delivered HDL/testbench/runner files match the executable revision above; subsequent commits contain documentation.

Evidence locations on the validation machine:

| Evidence | Location |
| --- | --- |
| Repository functional run | `build/modelsim/run-20260910-065458-111` |
| Repository analysis/synthesis | `build/quartus/run-20260910-065547-884` |
| Clean clone and independent probe artifacts | Exact current paths in [conversion report](VERILOG_CONVERSION.md). |

Each functional run includes `compile.log`, per-bench logs/WLF, `results.json`, and application VCD. Tool outputs remain local/ignored; compact waveform review artifacts are tracked. Reproduce with `./sim/run.ps1` and `./synth/run.ps1`; no prior generated library is needed.

Supplemental Verilog probes observed eight expected `FAIL` diagnostics followed by `$stop`: W = 0, S = 0, D = 0, D = -1, and unknown reset/enable on each of timer/debounce. A deliberately failing application check before its success flag yielded runner exit 4 with no success marker; normal completion yielded exit 0. Only the deliberately invalid W = 0 fixture additionally warned about zero replication; supported configurations compile and simulate without warnings. Those temporary sources are not part of the four committed positive benches. Process-timeout injection, arbitrary X/Z fault injection, and unused-state corruption recovery were not exhaustively tested.

## 12. Waveform observations

Recorded VCD data was parsed and inspected; [waveform observations](WAVEFORM_OBSERVATIONS.md) includes significant transition CSV and a plot derived from that data. This was waveform-data inspection, not a claim of manually opening the WLF GUI.

- Normal fill: pump starts at 170 ns, MID qualifies at 550 ns and cancels monitoring at 570 ns, FULL qualifies at 1,150 ns and pump stops at 1,170 ns.
- First absent-source window: pump starts at 2,390 ns, done rises at 3,670 ns (64 clocks later), and pump/protection update at 3,690 ns (65 clocks after start).
- FULL and MID response/expiry races produce qualified response and done together at 9,810 ns and 11,290 ns; their controller decisions occur 20 ns later without a fault latch.

These are measured accelerated simulation times. They are not measured physical pump or sensor response times. Noise, reset, manual recovery, and disable observations are also recorded in the waveform document.

## 13. Synthesis results

Quartus II 13.0.1 SP1 Analysis & Synthesis succeeded for both tops in fresh Verilog projects. Clean-checkout verification is recorded in the conversion report. Map reports estimate 224 logic elements/92 registers for `pulse_top`, and 241/96 for `water_tank_controller`, using representative Cyclone IV E EP4CE22F17C6. Each has zero errors and warning 20028: parallel compilation not licensed, so it runs serially.

The application also reports two original state registers losing fanouts during optimization. Diagnostics were reviewed; no latch, multiple-driver, truncation, or combinational-loop warning was observed. [Synthesis check](SYNTHESIS_CHECK.md) distinguishes estimated map counts from other informational resource fields. No fitter, physical timing closure, MTBF, post-synthesis equivalence, or hardware validation is claimed.

## 14. Known limitations

Full 32-bit maximum and full 5 s timer expirations were not run; those configurations were captured, decremented, and cancelled. All reduced-width configurations and representative full-width expirations were checked. INT_MAX debounce checks elaborated width only, while the default 20 ms interval was exercised fully.

The model has unitless discrete tank steps and instantaneous source-dependent flow. Monitoring covers the initial response; later flow loss after MID needs a new agreed requirement. Independent sensor channels are not an atomic encoded-word crossing. Physical values and external contracts remain provisional. [Known issues](KNOWN_ISSUES.md) records these limits and the resolved tool/diagnostic issues without labeling unrun tests as passing.

## 15. Future hardware implementation

Agree actual interfaces, clock/reset/tolerance, measured bounce/process timing, and recovery policy before board-specific implementation. Then perform appropriate device constraints, fitted timing/CDC analysis, controlled FPGA tests, and later sensor/driver/tank integration. The [future hardware document](FUTURE_HARDWARE_IMPLEMENTATION.md) records that path without adding physical implementation to this phase.

## 16. Conclusion

The reusable PULSE baseline and provisional digital application are implemented, self-checking Verilog simulations pass with freshly compiled libraries, measured waveform behavior matches the cycle contracts, and the installed Quartus synthesis flow accepts both production tops. Remaining work is explicitly external integration agreement, broader physical/maximum-duration validation where needed, and any subsequently authorized hardware phase.
