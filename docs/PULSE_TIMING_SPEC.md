# PULSE timing specification

Status: **Working digital timing specification; physical clock and application durations remain provisional.** Periodic behavior follows [OSC-CONTRACT-1](OSCILLATOR_CONTRACT.md), issued 2026-09-22.

Prepared: 2026-09-10. Assumptions refer to [PULSE_REQUIREMENTS.md](PULSE_REQUIREMENTS.md), A-01 through A-12.

## 1. Basis and proposed timebase

The supplied prompt fixes neither the actual system clock nor a sensor debounce/protection duration. There is no board, oscillator tolerance, pump response measurement, sensor datasheet, or tank geometry in the workspace. The numbers below are engineering examples for a reviewable digital contract; they must not be treated as calibrated water-tank limits.

Count **system-clock cycles** on rising edges of `clk`. Every interval begins from its own accepted event. This gives exact edge-based timing without a derived clock or the phase uncertainty of a shared free-running tick. Debounce, the external one-shot, and periodic generation advance independently while sharing a clock.

| Candidate | Benefit | Tradeoff / decision |
| --- | --- | --- |
| System-clock cycle counts | Exact N-cycle duration from any accepted start; one clock domain and simple verification. | More count bits for long intervals. **Selected working timebase.** |
| Shared 1 ms clock-enable | Fewer interval-count bits for long delays; still one clock domain. | First tick can occur less than 1 ms after start. Counting N ticks alone does not guarantee N full milliseconds; alignment or an extra timing rule is needed. Deferred. |
| Divided internal clock | A slower clock signal. | Adds clock-domain/clock-routing obligations without a current application need. Not proposed. |

The block name “Timer / Oscillator” does not require a physical oscillator or a new internal clock. OSC-CONTRACT-1 selects recurring clock-enable events in the existing domain for the user's oscillator-completion request. The periodic output does not gate debounce or one-shot timing.

## 2. Initial quantities and justification

| Quantity | Initial proposal | Basis / limit |
| --- | --- | --- |
| System-clock frequency, `CLOCK_FREQ_HZ` | 50,000,000 Hz | A-01: illustrative frequency from the prompt, selected for straightforward 20 ns arithmetic; actual clock requires Q-01. This is a description of the supplied clock, not a clock generator. |
| System-clock period | 20 ns | `1 / CLOCK_FREQ_HZ`. |
| Timer resolution | One `clk` period = 20 ns | Direct cycle counting. |
| Runtime timer configuration | Unsigned `cfg_timer_cycles[TIMER_WIDTH-1:0]` | A-03/A-04: sampled on each accepted start, expressed in whole system-clock cycles. |
| Timer width | `TIMER_WIDTH = 32` | Covers the 5 s fixture with room for longer examples, with no prescaler. Reassess after maximum timeout is agreed. |
| Smallest positive one-shot | 1 cycle = 20 ns | A start edge is followed by one full interval before completion. |
| Zero one-shot setting | Effective duration of 1 cycle | A-04: normalize zero rather than allow counter underflow or a combinational completion. There is no true zero-time operation. |
| Largest one-shot | 4,294,967,295 cycles = 85.8993459 s | `(2^32 - 1) / 50,000,000`; not `2^32` cycles. |
| Debounce duration | `DEBOUNCE_CYCLES = 1,000,000` = 20 ms | A-07: demonstration stability interval, rejecting shorter observed disturbances while adding 20 ms qualification latency. No measured bounce justifies it as a final sensor setting. |
| Debounce counter capacity | 20 bits if storing the inclusive range 0…1,000,000 | `ceil(log2(1,000,000 + 1)) = 20`; actual counter representation is deferred. |
| Illustrative protection window | 5 s = 250,000,000 cycles | A-09: 250 times the illustrative debounce duration and within the proposed timer range. A useful separated timescale for a digital demonstration; no physical suitability claim. |
| Minimum width for that 5 s example | 28 bits for 0…250,000,000 | Derived capacity; the proposed reusable timer retains a configurable 32-bit width. |
| Periodic configuration and width | Unsigned `cfg_period_cycles[PERIOD_WIDTH-1:0]`; independent `PERIOD_WIDTH = 32` | A-10 / OSC-CONTRACT-1: capture once on startup, retain across reloads, recapture only after sampled reset/disable and restart. |
| Periodic range | Effective P = 1 through 4,294,967,295 cycles | Zero maps to one. At 50 MHz: 20 ns through 85.8993459 s between events. P = 1 gives consecutive event cycles after startup. |
| Periodic example | 100 Hz; 10 ms; 500,000 cycles | Mathematical illustration of the included recurring-timing capability. No water-tank cadence is introduced; the application disables this function. |
| Accuracy | Exact configured clock count under the contract | Actual elapsed seconds depend on the real input clock; its tolerance is unknown. Synchronization and consumer latency are additional. |

Changing a declared `CLOCK_FREQ_HZ` value cannot change a physical clock. When a supplied clock changes, regenerate cycle configurations and update timing constraints/testbench assumptions together. The eventual RTL need not carry a frequency parameter if it only consumes already-calculated cycle counts.

## 3. Conversion, rounding, and range

For a requested positive physical interval `t_req` in seconds at configured frequency `f_cfg`:

```text
N = ceil(t_req * f_cfg)
t_nominal = N / f_cfg
0 <= t_nominal - t_req < 1 / f_cfg
1 <= N <= 2^TIMER_WIDTH - 1
```

Use ceiling conversion so a positive requested duration is not rounded down. Validate range before driving the configuration bus; never wrap or silently truncate an out-of-range value. Arithmetic used to form cycle counts and widths must be wide enough for intermediate results. Multiplying milliseconds by frequency in a narrow signed integer is not an acceptable conversion strategy.

For storage of the inclusive integer range `0…N_max`, the required capacity is `max(1, ceil(log2(N_max + 1)))` bits. The architecture selects a remaining-cycle count with this inclusive capacity. Elaboration constraints: `TIMER_WIDTH >= 1`, `PERIOD_WIDTH >= 1`, `SENSOR_CHANNELS >= 1`, and `1 <= DEBOUNCE_CYCLES <= 2,147,483,647`. The same ceiling conversion applies to a requested periodic interval, using the independent bound `1 <= P <= 2^PERIOD_WIDTH - 1`. Zero debounce is an invalid configuration, unlike the explicitly normalized runtime timer/periodic zero values. Compute width using an overflow-safe expression as specified in the architecture.

With actual clock frequency `f_actual`, the physical interval is `N / f_actual`. For an agreed frequency range `[f_min, f_max]`, its bounds are `[N / f_max, N / f_min]`. No numeric oscillator error or accuracy percentage is known. The rounding guarantee above is relative to the configured frequency and does not guarantee a minimum physical delay under a faster actual clock.

## 4. One-shot edge contract

These are the working one-shot observable semantics, preserved by oscillator completion. All sampled conditions refer to inputs and status **immediately before** a rising edge; output changes described below occur immediately after that edge.

1. On edge `e0`, accept `timer_start` only when `reset = 0`, `enable = 1`, `timer_cancel = 0`, and `timer_busy = 0`.
2. Capture `cfg_timer_cycles` at `e0`; let `N_eff = max(1, captured_value)`. Assert `timer_busy` after `e0`; `timer_done` is low. The start edge consumes no elapsed interval.
3. If uninterrupted, complete on edge `eN_eff`, exactly `N_eff` clock periods after `e0`. Deassert busy and assert done after that edge.
4. `timer_done` stays asserted for one clock period, then clears at the next edge. A synchronous consumer observes/captures that event on the following edge; its own action may add latency.
5. Configuration changes after `e0` do not affect the active interval. There is no queued or automatic periodic operation.

Example: N = 3, with no competing controls:

| Edge | Action | Busy after edge | Done after edge | Elapsed time since start |
| --- | --- | --- | --- | --- |
| `e0` | Accept start / capture 3 | 1 | 0 | 0 |
| `e1` | Continue | 1 | 0 | 1 cycle |
| `e2` | Continue | 1 | 0 | 2 cycles |
| `e3` | Complete | 0 | 1 | 3 cycles |
| `e4` | Clear done; may accept a new start | 0, or 1 for a new operation | 0 | 4 cycles |

Values 0 and 1 both complete at `e1`; maximum value completes at `e(2^TIMER_WIDTH-1)`. No overflow/rollover is part of the contract.

### Simultaneous controls and repeated operation

Priority is **reset > disable > timer_cancel > active counting/expiry > idle start**.

| Condition sampled on an edge | Result after that edge |
| --- | --- |
| `reset = 1` | Abort, busy/done cleared; sensor output/validity reset as specified in the interface. |
| `enable = 0` | Abort without done; clear sensor output/validity; ignore start. Re-enable requires a fresh start and fresh qualification. |
| `timer_cancel = 1` | Abort without done, including on the expiration edge; ignore simultaneous start. Debounce continues if enabled. |
| Start while busy, including the expiration edge | Ignore start; existing interval progresses/completes normally. |
| Start at the edge after expiry, when old busy is zero | Accept a new interval; clear the previous done event. |

`timer_start` is a caller-generated one-cycle strobe. This proposal does not add edge-detection state: if the caller incorrectly holds start high through a later eligible idle edge, another operation can start. `timer_cancel` may remain high to inhibit starts. Cancellation and disable are not pause/resume controls.

## 5. Sensor qualification timing

The candidate inputs are independent Boolean channels. PULSE provisionally owns input synchronization (A-06), but confirmation is required from SENTINEL. The stability interval is measured at the **synchronized sample observed by the qualification logic**, not directly from an analog transition or asynchronous pin.

Let `d0` be the edge on which a new candidate value is first observed after synchronization. The candidate must remain the same at every subsequent observation through edge `dN_db`, where `N_db = DEBOUNCE_CYCLES`. Accept it after `dN_db`, following **N_db complete clock intervals**. Thus this convention examines the candidate at `N_db + 1` observation edges, including `d0`; it is not an N-sample rule that counts the first observation as elapsed time.

- A differing sample restarts the full qualification interval from that edge.
- A differing sample on the expiration edge takes priority over acceptance; the old candidate is not accepted.
- Returning to the last accepted value before expiration leaves the accepted output unchanged.
- Both rising and falling changes use the same initial interval proposal.
- During a pending change, the last qualified output remains available. Once set, validity stays high until reset/disable; it does not assert that the raw signal currently agrees with the output.
- At startup, validity is low and the input must qualify for the complete interval, even if its value equals the zero reset output. A two-stage readiness pipeline excludes reset-filled synchronizer values: first enabled capture at a0, second at a1, first qualifier observation at a2, acceptance at a(2+D) for a stable input. See the architecture for the edge table.
- Independent channels can update on different edges; per-channel qualification provides no atomic multi-bit word guarantee.

This rejects short **observed** disturbances. RTL simulation cannot guarantee rejection of every analog glitch between sampling edges or prove metastability performance. The digital baseline has D+2 cycles from first-stage capture of a persistent transition to qualified output, plus any input phase wait before capture. A registered consumer observes the result one edge later. This pipeline latency is additional to the nominal 20 ms and is not a physical metastability bound.

## 6. Protection-window budget and ownership

PULSE exposes the one-shot duration and elapsed event; GUARDIAN starts/cancels it and determines the application consequence. The trigger event (pump request versus effective pump enable), expected qualified response, and reset/recovery behavior remain Q-04/Q-06. No dry-run threshold has been validated.

The integration budget must include the expected process response plus synchronization, debounce, GUARDIAN observation/decision latency, and an agreed margin. Starting a timer on a pump request also includes any delay before effective pump enable. A response that physically occurs just before a deadline may be reported after it because it is still being qualified.

With the proposed PULSE priority, cancel already high before the expiration edge suppresses `timer_done`. A GUARDIAN cancel derived from a newly registered sensor output cannot be assumed to act retroactively on that same edge. If GUARDIAN observes a qualified response and a completion event together, its decision priority must be agreed explicitly. The provisional PULSE contract makes both observations deterministic without choosing the pump/fault policy.

The 5 s example is an application configuration value, not a second timer feature or a hardwired protection limit. One timer can measure only one external interval at a time; overlapping pump-start delays and monitoring windows require further requirements review.

## 7. Periodic events: OSC-CONTRACT-1

F-11 is included in the current oscillator-completion scope. After a sampled clear, latch the period on the first rising edge with reset low and both global `enable` and `periodic_enable` high. Treat that as `p0`; let P = max(1, captured unsigned configuration). Produce the first registered `periodic_tick` after P full intervals at `pP`, then at `p2P`, `p3P`, and so on. Configuration remains captured across every reload; live changes, including on expiry, apply only after reset/global disable/local disable is sampled and operation restarts.

The event is one clock interval wide for P > 1, with P−1 low intervals. P = 1 requests an event on every active clock edge after startup: tick is low after p0 and remains high after p1 onward until cleared. A low gap is not promised. A clocked consumer must count high samples, not tick rising transitions. It sees a newly registered tick one edge later: first action at `p(P+1)` and subsequent actions spaced P edges apart.

Sampled reset, global disable, or local periodic disable clears output, active state, retained period, and count. Clearing wins over an expiry on that same edge. Clearing on a later edge cannot undo a preceding high interval or a consumer's observation of it. Re-enable captures a new P and waits a complete period; there is no phase resume. `timer_start`/`timer_cancel` and sensor changes do not affect periodic timing. Local periodic disable does not affect the timer or sensors.

| Expected edge | P = 3 tick after edge | P = 1 tick after edge | Meaning |
| --- | --- | --- | --- |
| p0 | 0 | 0 | Capture; no elapsed interval. |
| p1 | 0 | 1 | First P = 1 event. |
| p2 | 0 | 1 | Second P = 1 event. |
| p3 | 1 | 1 | First P = 3 event; third P = 1 event. |
| p4 | 0 | 1 | A separate consumer first observes the P = 3 event. |
| p6 | 1 | 1 | Second P = 3 event. |
| p9 | 1 | 1 | Third P = 3 event. |

For actual clock frequency f, event spacing is P/f and event rate is f/P. At illustrative 50 MHz: P = 2 gives 40 ns and 25 MHz events; P = 3 gives 60 ns and 16.666666… MHz events; P = 500,000 gives 10 ms and 100 Hz; P = 50,000,000 gives 1 s and 1 Hz. P = 1 gives 50 MHz event opportunities with a continuously high tick after startup. These are expected calculations, not physical-clock specifications or claims that every example was simulated. [OSC-CONTRACT-1](OSCILLATOR_CONTRACT.md) includes full edge, reset/restart, configuration, frequency, and range tables.

## 8. Later verification and present evidence

Unit simulations retain the illustrative clock and use small elaboration/configuration counts for accelerated boundary checks. For example, four debounce cycles and a 32-cycle window mean 80 ns and 640 ns at 50 MHz, not 20 ms and 5 s. The implemented suite exercises every 8-bit timer setting, selected default-width operations, and a full default-duration debounce; application scenarios use D = 3 and a 64-cycle window. Actual results and unrun long-duration limits are recorded in the final report.

The clock period, example cycle counts, maximum timer duration, and required example widths above were independently recalculated in PowerShell during the initial documentation pass. Those were arithmetic checks, not simulator or synthesis results. The architecture now fixes the digital pipeline schedule; subsequent simulation evidence is recorded separately. Physical application response budgets remain provisional.

Periodic verification must distinguish reduced-width exhaustive checks, representative 32-bit checks, and bounded large-count no-premature-event/abort checks. A bounded check does not establish completion of the entire 32-bit maximum period. The contract's expected tables and consumer counts are design references; actual outcomes are recorded in the verification report, waveform record, and final report.
