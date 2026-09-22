# Known issues and verification limits

Updated: 2026-09-22. There is no known failing legal-input regression case in the delivered OSC-CONTRACT-1 baseline. This is not a proof that every possible implementation fault is absent.

Implementation language: Verilog HDL (Verilog-2001). Current periodic implementation, verification, and limitations are recorded in [OSCILLATOR_COMPLETION.md](OSCILLATOR_COMPLETION.md). The [conversion record](VERILOG_CONVERSION.md) preserves the historical 2026-09-10 four-bench baseline; it is not the current source-count or resource report.

## Current verification evidence

The seven positive benches passed in workspace run `build/modelsim/run-20260922-103440-575`; both production tops passed Analysis & Synthesis in `build/quartus/run-20260922-102633-279`. The unchanged timer/debounce/application suites retain their recorded counts and deadlines. The top bench retains P01-P07 and adds P08-P11 concurrency cases. New periodic smoke, independent unit, and checker self-test benches pass; the checker-only bench's nine deliberately bad samples are expected detections, not DUT failures.

Final clean-clone evidence uses exact executable revision `15857ae6b79d84b10c619ce947af10efca7a1de6` at `C:\Users\HP\AppData\Local\Temp\pulse periodic final 696fbc152aed4b4c8c5c2c546c752c2f`:

| Check | Artifact path relative to final clone | Result |
| --- | --- | --- |
| Fresh compilation and complete positive regression | `build/modelsim/run-20260922-105734-427` | All seven benches PASS; no compiler/simulator warnings or errors. |
| Fresh synthesis for both production tops | `build/quartus/run-20260922-105734-620` | Both PASS; core 385 estimated logic elements / 158 registers; application 241 / 96. Warning 20028 only for each top. |

These are digital simulation and synthesis results. They do not establish external interface approval, calibrated physical durations, fitted timing, or physical hardware operation.

## Resolved issues

K-01 through K-06 describe fixes from the original implementation and Verilog conversion. Their four-bench references are historical evidence; current seven-bench results are above.

| ID | Severity / reproduction | Cause | Fix | Verification status |
| --- | --- | --- | --- | --- |
| K-01 | Medium; successful TB reported exit 3 at normal finish on ModelSim 10.1d | `$finish` also invokes `onbreak`; initial runner treated every break as failure. | Resume macro, then require explicit test_passed, transcript marker, and absence of error diagnostics. | Successful application exits 0; a TEMP intentional failing procedural check before success exits 4. Repository regression passes. |
| K-02 | Medium; compile attempted `build/modelsim/src/...` | ModelSim `do` macro did not set Tcl `info script` for repository-path discovery. | Invoke compile script with Tcl `source`. | Fresh repository compilation passes; clean-checkout path test recorded separately. |
| K-03 | Medium; successful timer lacked transcript success marker | Tcl `puts` output was not recorded as expected in the 10.1d transcript. | Use ModelSim `echo` for completion marker; set WLF name on the inner design load. | Four test logs contain PULSE_TEST_OK and separate named WLF files exist. |
| K-04 | Low; width-one timer produced zero-replication warning | COUNT_ONE used a zero-length concatenation at W=1. | Width-declared unsigned constant uses `1'b1` extension. | W=1 tests and final clean compiler transcript pass without that warning. |
| K-05 | Medium diagnostic gap; reset/enable X hid other invariant checks | All checks were gated on controls being known and enabled. | Add independent sampled knownness checks outside that gate, synthesis-excluded. | Four TEMP probes for reset=X/enable=X on timer/debounce produce expected `FAIL` diagnostics and `$stop`. Legal-input regression passes. |
| K-06 | Required implementation-language compliance | Previous source syntax and project settings did not meet the Verilog HDL requirement. | Convert all 11 RTL/model/bench files to Verilog-2001 `.v` sources and update tool inputs; procedural checks print `FAIL` and call `$stop`. | All four clean Verilog regressions preserve original counts/deadlines; both Quartus tops pass. TEMP runner failure returns 4 with `test_passed=0`; a deliberate incompatible declaration is rejected by the compiler with exit 2. |

## Open limitations and integration dependencies

| ID | Severity / scope | Reproduction or evidence | Disposition |
| --- | --- | --- | --- |
| L-01 | Team integration dependency | No external interface, real clock/tolerance, bounce measurement, calibrated window, or recovery agreement supplied. | Q-01…Q-08 remain open. Working assumptions and adapter are labeled provisional. |
| L-02 | Verification coverage limit | Full 32-bit maximum interval and full 250,000,000-cycle/5 s timer expiry are not run. Tests load, inspect progression, and cancel those values. | Every 8-bit interval expires under exact-edge checks; W=1 and representative W=32 expiry also pass. Do not claim full-duration 32-bit maximum verification. |
| L-03 | Verification coverage limit | Maximum debounce value tests elaborated width, not billions of qualification cycles. | D=1, D=4, and full default D=1,000,000 qualification are exercised. |
| L-04 | Physical scope limit | No hardware, analog noise, CDC MTBF, fitted timing, electrical interface, or pump-driver test exists. | Future work; RTL samples cannot prove physical metastability behavior. |
| L-05 | Application model limit | Initial MID response cancels monitoring; later flow loss during confirmed filling does not start a new watchdog. | Deliberate APP-04 scope, not a complete fault diagnosis. Extend only with agreed requirements. |
| L-06 | Model fidelity limit | Unitless 0…100 tank with discrete fill/drain steps and instantaneous source-dependent pump flow. | Digital functional demonstration, not a hydraulic/physical prediction. |
| L-07 | Tool warning | Quartus warning 20028 on both tops. | Parallel compilation unavailable under installed license; serial synthesis passes. |
| L-08 | Diagnostic evidence portability | Original timer/debounce invalid-parameter/unknown-control probes and five new periodic diagnostic probes use temporary sources outside the seven positive benches. | Supplemental observations; standard positive regression does not reproduce those probes. Periodic runner failure injection is now reproducible with `./sim/run.ps1 -Test pulse_periodic_tb -InjectFailure`; its expected failure is documented separately. Unused-state recovery is specified but not fault-injection verified. |
| L-09 | Invalid-parameter diagnostic only | Deliberate zero timer/period widths emit ModelSim `vsim-8602` for zero replication before the positivity guard prints `FAIL` and stops. | Width zero is unsupported. Legal-width positive compilation/simulation is warning-free; width one is valid. The negative-probe warning is not a valid-design warning. |
| L-10 | Periodic waveform/assignment boundary | OSC-CONTRACT-1 produces registered enable events; P = 1 holds tick HIGH continuously after p1, representing an event each clock cycle. It does not produce a 50% duty square wave. | Consumers count high samples on the system clock, not tick rising transitions. A different square-wave assignment interpretation needs an amended contract and tests. Supervisor/external-team acceptance is not claimed. |
| L-11 | Periodic verification coverage limit | Full expiry of maximum 32-bit period 4,294,967,295 cycles is unrun. At illustrative 50 MHz that interval is 85.8993459 s. | Every 4-bit setting completes at least three periods; width one and representative 32-bit periods are exercised. Maximum-period public-output checks establish no premature event during the bounded observation and correct abort/restart, not full-duration expiry. |
| L-12 | Application integration scope | The water-tank controller holds periodic enable low, supplies zero periodic configuration, and leaves tick unused. No external event consumer is agreed. | Recurring-event consumption is demonstrated by a synchronous unit-bench event counter; top tests exercise enabled concurrency. Existing water-tank behavior is retained. |

The eight historical conversion parameter/control probes, intentional application-check failure, and compiler rejection evidence remain under `C:\Users\HP\AppData\Local\Temp\pulse-verilog-diagnostics-3b18d728f1b04b5583b11da343865f63`. All eight emitted the expected `FAIL` diagnostic and stopped before the TEMP driver completion marker. The historical independent positive regression is under `C:\Users\HP\AppData\Local\Temp\pulse-verilog-bench-d98df18a568e4174b9517b863f0ba81a`.

The five periodic diagnostic probes are under `C:\Users\HP\AppData\Local\Temp\pulse-periodic-diagnostics-adefaf61ef72462ba31838e8896f1749`. They cover zero width, unknown reset, unknown global/local enables, and unknown accepted configuration, each with the expected diagnostic and premature stop. Reproducible periodic failure injection is recorded in workspace run `build/modelsim/run-20260922-102632-929`: simulator exit 4 and no success marker. These negative outcomes are expected diagnostic evidence; they are separate from positive PASS results.

Periodic generation is included in the current working scope under [OSC-CONTRACT-1](OSCILLATOR_CONTRACT.md). The additional timer cancellation-one-cycle-before-expiry check and full five-second timer run remain separate backlog items; oscillator completion does not claim to add or execute them. No unrun case is reported as PASS.
