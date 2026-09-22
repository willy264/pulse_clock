# PULSE final software report

Updated: 2026-09-22. Implementation language: Verilog HDL (Verilog-2001).

The reusable PULSE core now implements a configurable one-shot timer, independent sensor synchronization/debounce, and a configurable periodic clock-enable generator. The user requested execution of all five oscillator task packages; their implemented scope and evidence are recorded in [OSCILLATOR_COMPLETION.md](OSCILLATOR_COMPLETION.md). The output choice is the existing periodic-tick proposal, explicitly adopted as working contract [OSC-CONTRACT-1](OSCILLATOR_CONTRACT.md); no supervisor or external-team approval is claimed.

## Architecture and timing

`pulse_top` connects `pulse_timer`, `pulse_periodic`, and one `pulse_debounce` per sensor in one external-clock domain. The five production source files include the provisional water-tank controller. Timer and debounce behavior is preserved. Periodic generation captures P = max(1, configuration), waits P full intervals for the first event, and repeats every P intervals using the captured period. Reset/global/local disable clears phase; re-enable captures a new period. P = 1 is an enable on consecutive cycles, with no LOW gaps. Timer cancellation and sensor noise do not restart periodic timing.

The illustrative clock remains 50 MHz. This block does not generate a new internal clock or implement a physical/square-wave oscillator. Port definitions, widths, ownership, and consumer observation latency are in [interface](PULSE_INTERFACE.md), [timing](PULSE_TIMING_SPEC.md), and [architecture](PULSE_ARCHITECTURE.md).

## Verification evidence

The exact executable revision is `15857ae6b79d84b10c619ce947af10efca7a1de6`. ModelSim-Altera 10.1d compiled all 16 HDL sources in Verilog-2001 mode. Seven positive benches pass with no compiler/simulator warnings or errors:

| Bench | Checks/cases | Finish time |
| --- | --- | --- |
| Timer | 100,985 checks | 684,131 ns |
| Debounce | 1,000,277 checks, including the full default interval | 20,004,271 ns |
| Periodic smoke | 35 checks | 711 ns |
| Periodic checker self-test | 99 checks; nine expected bad observations rejected | 992 ns |
| Periodic real-module unit | 9,330 checks; zero checker errors | 87,932 ns |
| PULSE integration | P01-P11, including periodic concurrency | 2,931 ns |
| Water-tank application | 715 checks / 684 cycles; A-G | 13,671 ns |

Workspace run: `build/modelsim/run-20260922-103440-575`. Baseline reproduction, final clean-checkout provenance, temporary diagnostics, and a reproducible intentional failure returning simulator exit 4 are recorded in the completion report. [Verification plan](PULSE_VERIFICATION_PLAN.md) and [traceability](TRACEABILITY_MATRIX.md) map cases to requirements; counts are not coverage percentages.

## Measured behavior and synthesis

The recorded application still matches all 127 baseline settled event snapshots. Its initial-response, fault latch, recovery, and threshold assumptions are unchanged. The application explicitly disables periodic operation. Independent periodic and concurrency CSV/PNG evidence shows exact event spacing, phase independence, reset/disable priority, and the next-edge consumer response. [Waveform observations](WAVEFORM_OBSERVATIONS.md) provides measured timestamps and extraction commands.

Quartus II 13.0.1 SP1 Analysis & Synthesis passes for both tops in fresh projects. The core estimates 385 logic elements and 158 registers; the unchanged application estimates 241 and 96 because its disabled extension is optimized away. Both have zero errors and only warning 20028 (parallel compilation unavailable under the license; serial compilation succeeds). No latch, width-truncation, multiple-driver, or unsupported-construct warning was reported. [Synthesis report](SYNTHESIS_CHECK.md) records scope and report details.

## Scope and remaining limits

All software tasks for the adopted periodic-tick contract are addressed. [Task disposition](PULSE_OSCILLATOR_TEAM_TASKS.md) links each assignment to its deliverable, and [demonstration instructions](OSCILLATOR_DEMO.md) provide the review sequence.

The periodic maximum-width setting has bounded checks; full maximum-duration expiry is unrun. Existing full five-second/max timer expiry and the explicit additional cancel-one-cycle-before-expiry case remain separate backlog. Independent Boolean sensor channels are not an atomic encoded-word crossing. Tank/pump models remain discrete, uncalibrated software models. Q-01 through Q-08 still require actual external integration agreement.

No fitter, board programming, physical timing closure, analog metastability measurement, hydraulic validation, or physical oscillator is claimed. See [known issues](KNOWN_ISSUES.md) and the [future hardware path](FUTURE_HARDWARE_IMPLEMENTATION.md). The [Verilog conversion report](VERILOG_CONVERSION.md) preserves the earlier conversion evidence as historical provenance.
