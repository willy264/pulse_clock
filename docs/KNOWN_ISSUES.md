# Known issues and verification limits

Updated: 2026-09-10. There is no known failing legal-input regression case in the delivered baseline. This is not a proof that every possible implementation fault is absent.

Implementation language: Verilog HDL. Conversion evidence is in [VERILOG_CONVERSION.md](VERILOG_CONVERSION.md). All original functional checks passed again in clean workspace run `build/modelsim/run-20260910-065458-111`; both production tops passed clean synthesis in `build/quartus/run-20260910-065547-884`.

## Resolved issues

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
| L-08 | Diagnostic evidence portability | Invalid-parameter/unknown-control and deliberate-check-failure probes were run from temporary test sources, outside the four committed positive benches. | Supplemental observed evidence; the standard runner does not reproduce these negative probes automatically. Unused-state recovery is specified but not fault-injection verified. |
| L-09 | Invalid-parameter diagnostic only | Deliberate `TIMER_WIDTH=0` TEMP fixture emits ModelSim `vsim-8602` for a zero replication multiplier before the positivity guard prints `FAIL` and stops. | Width zero is outside the supported range. All legal-width compilation/simulation runs are warning-free; W=1 remains valid. Do not interpret the warning from this negative probe as a valid-design warning. |

The eight current parameter/control probes, the intentional application check failure, and compiler rejection evidence are under `C:\Users\HP\AppData\Local\Temp\pulse-verilog-diagnostics-3b18d728f1b04b5583b11da343865f63`. All eight emitted the expected `FAIL` diagnostic and stopped before the TEMP driver completion marker. The independent positive regression is under `C:\Users\HP\AppData\Local\Temp\pulse-verilog-bench-d98df18a568e4174b9517b863f0ba81a`. The [verification plan](PULSE_VERIFICATION_PLAN.md) records their scope; the conversion report records the current executable revision and final fresh-checkout evidence.

Periodic generation is a deferred optional feature with no confirmed consumer; its absence is not a failed requirement. No unrun case is reported as PASS.
