# PULSE oscillator contract: OSC-CONTRACT-1

Issued: 2026-09-22. Status: **Working implementation contract selected for the user's oscillator-completion request. External assignment interpretation, physical clock assumptions, and other-team interfaces remain provisional.**

## 1. Decision and scope

The original project brief made periodic generation conditional. The later request to implement the [oscillator team tasks](PULSE_OSCILLATOR_TEAM_TASKS.md) makes completing the oscillator capability part of the current work. This revision selects the repository's existing registered periodic-tick proposal as the working implementation decision. It does not claim supervisor approval or an agreed VOICE/GUARDIAN consumer.

`pulse_periodic` provides repeated synchronous clock-enable events while the existing `pulse_timer` provides one elapsed event per accepted start. This demonstrates the reusable building block's recurring timing capability. A synchronous event counter in the periodic unit bench demonstrates consumption without inventing water-tank behavior. The water-tank controller keeps the new function disabled.

The output is `periodic_tick`. All production sequential logic continues to use the externally supplied `clk`; the tick is data/enable. A square-wave alternative would require a different half-period and duty-cycle contract. That alternative is outside OSC-CONTRACT-1. Physical implementation remains outside this work.

Implement in Verilog-2001 using `src/pulse_periodic.v`. Module, standalone tests, top-level wiring, and tool source lists must use this revision. Any amendment affecting ports or edge behavior must update the contract and its tests together; successful local checks do not finalize external agreements.

## 2. Interface

The standalone parameter is `PERIOD_WIDTH = 32`, a positive integer independent of `TIMER_WIDTH`. Let R denote `PERIOD_WIDTH`. Counts are unsigned system-clock cycles, with bus values 0 through `2^R - 1`. A supplied zero is normalized to an effective period of one cycle.

| Port | Direction / width | Meaning and active level | Reset obligation/state | Sampling and endpoints |
| --- | --- | --- | --- | --- |
| `clk` | Input / 1 | External rising-edge system clock. | Must run to sample reset. | System clock owner → all periodic state. |
| `reset` | Input / 1 | Active-high synchronous reset. | Producer asserts across a rising edge before operation. | System reset owner → periodic state; clearing wins expiry. |
| `enable` | Input / 1 | Active-high global PULSE operation enable. | May be low through reset. | Integration → periodic state; sampled low clears phase/output. |
| `periodic_enable` | Input / 1 | Active-high local periodic enable. | Producer supplies a known value; normally low until operation is wanted. | Synchronous caller → periodic state; sampled low clears only this function. |
| `cfg_period_cycles` | Input / R | Requested input-clock cycles per event; no active polarity. | Externally owned; ignored during reset/disable. | Synchronous caller → period capture; known and in range on the first jointly enabled edge. |
| `periodic_tick` | Output / 1 | Registered active-high event/clock enable. | Zero after sampled reset/global disable/local disable. | Periodic block → synchronous consumer; first assertion after P complete intervals, described below. |

All inputs must meet `clk` timing. A count bus from a different domain requires a separately agreed coherent transfer; this module introduces no cross-domain handshake. No value is promised before an initial reset edge. X/Z controls or accepted configuration are invalid simulation inputs, not additional operating modes.

`pulse_top` appends `PERIOD_WIDTH = 32` after its existing three parameters and exposes `periodic_enable`, `cfg_period_cycles[PERIOD_WIDTH-1:0]`, and `periodic_tick`. Existing timer and sensor parameters/ports retain their meanings. Use named connections, and explicitly tie `periodic_enable` low and the configuration to zero in integrations that do not use the feature. The application leaves the unused tick output unconnected.

## 3. Exact edge behavior

All guards use values immediately before a rising edge; registered updates occur after it.

1. Sampling `reset = 1`, `enable = 0`, or `periodic_enable = 0` clears the captured period, remaining count, active flag, and output. These clear conditions have the same effect and all outrank expiry/capture.
2. After clearing, the first edge with reset low and both enables high is `p0`. Capture `P = max(1, cfg_period_cycles)` and start active operation; tick stays low. This edge consumes no elapsed interval.
3. With uninterrupted operation, assert tick after `pP`, `p2P`, `p3P`, and so on. The interval from capture to first assertion and between assertions is exactly P full `clk` periods.
4. Preserve the captured period across reloads. Live configuration changes while active, including on expiration edges, do not change the current or later periods.
5. A sampled clear discards the phase. A later first jointly enabled edge becomes a new `p0`, captures the then-current configuration, and waits a new full period. An enable transition entirely between sampling edges has no effect.

For P > 1 each event is high for one clock interval and low for P−1 intervals. For P = 1, tick is low after `p0` and high after every edge from `p1` onward until cleared. These are consecutive event cycles, with no promised low gap. Count events at `posedge clk` when tick is high; counting tick rising edges would miss consecutive P = 1 events.

A separate clocked consumer sees the previous tick value. If tick first asserts after `pP`, that consumer can first act at `p(P+1)`, then every P edges. A clear sampled at an expiry edge suppresses the new event. A clear at a later edge cannot undo an event already high during the preceding interval; consumers needing reset/disable behavior must apply their own documented gating.

`timer_start`, `timer_cancel`, timer configuration, and sensor changes cannot affect periodic phase. Local periodic enable/configuration cannot affect one-shot or debounce progress. Global reset/disable clears all PULSE functions under their existing contracts.

## 4. Worked expected schedules

These tables describe expected contract behavior, not measured simulation results. Edges are relative to the accepted capture at p0. Example consumer counts start at zero and use `if (periodic_tick)` in a separate `posedge clk` process.

| Edge, P = 3 | Periodic action | Tick after edge | Consumer count after edge |
| --- | --- | --- | --- |
| p0 | Capture 3; start. | 0 | 0 |
| p1 | Advance. | 0 | 0 |
| p2 | Advance. | 0 | 0 |
| p3 | First event; reload captured 3. | 1 | 0 |
| p4 | Advance; consumer observes first event. | 0 | 1 |
| p5 | Advance. | 0 | 1 |
| p6 | Second event; reload captured 3. | 1 | 1 |
| p7 | Advance; consumer observes second event. | 0 | 2 |
| p8 | Advance. | 0 | 2 |
| p9 | Third event; reload captured 3. | 1 | 2 |
| p10 | Advance; consumer observes third event. | 0 | 3 |

| Edge, supplied period 0 or 1 | Periodic action | Tick after edge | Consumer count after edge |
| --- | --- | --- | --- |
| p0 | Capture effective P = 1. | 0 | 0 |
| p1 | First event; reload 1. | 1 | 0 |
| p2 | Second event; reload 1. | 1 | 1 |
| p3 | Third event; reload 1. | 1 | 2 |
| p4 | Fourth event; reload 1. | 1 | 3 |

Configuration/restart example, initially P = 3:

| Edge | Input/action | Tick after edge | Contract consequence |
| --- | --- | --- | --- |
| p0 | Jointly enable with configuration 3. | 0 | Capture 3. |
| p1 | Change live configuration to 2. | 0 | Captured period stays 3. |
| p3 | First expiry; configuration remains 2. | 1 | Reload captured 3. |
| p6 | Second expiry. | 1 | Reload captured 3 again. |
| p9 | Sample local disable at the third expected expiry. | 0 | Clear wins; third event is suppressed. |
| p10 = q0 | Re-enable with configuration 2. | 0 | Capture 2 and restart phase. |
| p11 = q1 | Advance. | 0 | One full interval elapsed. |
| p12 = q2 | First new expiry. | 1 | Two full intervals after q0. |
| p14 = q4 | Second new expiry. | 1 | Repeat with captured 2. |
| p16 = q6 | Third new expiry. | 1 | Repeat with captured 2. |

Replacing the clear at p9 with synchronous reset or global disable produces the same periodic result. Global controls also clear the existing timer/sensor functions; local periodic disable does not. The unit suite must exercise all three clear sources and restart paths, not infer their verification from this table.

## 5. Frequency, range, and accuracy

For actual input frequency `f_clk`, event spacing is `T_event = P / f_clk` and event rate is `f_event = f_clk / P`. At the illustrative 50 MHz clock, one input period is 20 ns:

| Supplied count | Effective P | Expected event spacing | Expected event rate | Tick shape |
| --- | --- | --- | --- | --- |
| 0 or 1 | 1 | 20 ns | 50 MHz events | Continuously high after startup; one event per clocked observation. |
| 2 | 2 | 40 ns | 25 MHz | One high interval, one low interval. |
| 3 | 3 | 60 ns | 16.666666… MHz | One high interval, two low intervals. |
| 4 | 4 | 80 ns | 12.5 MHz | One high interval, three low intervals. |
| 500,000 | 500,000 | 10 ms | 100 Hz | 20 ns high per 10 ms period. |
| 50,000,000 | 50,000,000 | 1 s | 1 Hz | 20 ns high per 1 s period. |
| 4,294,967,295 | 4,294,967,295 | 85.8993459 s | approximately 0.011641532 Hz | Maximum 32-bit period. |

These rates are recurring enable-event rates; P = 1 does not produce a 50 MHz toggling waveform. The 100 Hz and 1 Hz rows are mathematical examples, not new application requirements or evidence of long-duration tests. The 50 MHz input remains an illustrative assumption. Actual clock tolerance and configured-frequency rounding follow [timing specification](PULSE_TIMING_SPEC.md); no physical oscillator precision is known.

## 6. Implementation and evidence boundaries

The implementation uses two R-bit storage registers, `captured_period` and `remaining`, plus `active` and `periodic_tick`. The captured value is held across repeated countdowns. On active expiry, reload remaining from captured period and assert tick; otherwise decrement remaining and clear tick. Do not resample the live input on reload and do not add one to a maximum-width count.

Production source lists contain five files: the timer, debounce, periodic generator, PULSE top, and application controller. ModelSim, Quartus, and TerosHDL must include the new module consistently. The reusable PULSE synthesis top exposes periodic inputs/output so the feature is retained; the application disables it, permitting unused periodic logic to be removed there.

Required evidence includes a separate developer smoke bench; independent unit checks of first/repeated events, zero/minimum, odd/even and all reduced-width values, width, frozen configuration, all clear sources at expiry, restart, and bounded large counts; checker self-tests; concurrent top-level tests; existing regression preservation; both synthesis tops; measured waveforms; and clean-checkout reproduction. Exact full maximum duration is not claimed by bounded no-premature-event/abort tests. Actual commands/results belong in the verification, synthesis, demo, and final-report records; this contract alone is not PASS evidence.

External questions remain: whether the supervisor ultimately requires a square wave instead, the physical clock/tolerance, and whether another team will consume periodic events with a particular cadence/domain. These do not prevent implementing and verifying this explicit working decision, and they must not be reported as resolved without evidence.
