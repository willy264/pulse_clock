# PULSE initial timing specification

Status: **PROVISIONAL — draft for review, not an approved hardware timing specification.**

Prepared: 2026-09-10. Assumptions refer to [PULSE_REQUIREMENTS.md](PULSE_REQUIREMENTS.md), A-01 through A-12.

## 1. Basis and proposed timebase

The supplied prompt fixes neither the actual system clock nor a sensor debounce/protection duration. There is no board, oscillator tolerance, pump response measurement, sensor datasheet, or tank geometry in the workspace. The numbers below are engineering examples for a reviewable digital contract; they must not be treated as calibrated water-tank limits.

Propose counting **system-clock cycles** on rising edges of `clk`. Every interval begins from its own accepted event. This gives exact edge-based timing without a derived clock or the phase uncertainty of a shared free-running tick. Debounce and the external timer must advance independently even if they share a clock.

| Candidate | Benefit | Tradeoff / decision |
| --- | --- | --- |
| System-clock cycle counts | Exact N-cycle duration from any accepted start; one clock domain and simple verification. | More count bits for long intervals. **Initial proposal.** |
| Shared 1 ms clock-enable | Fewer interval-count bits for long delays; still one clock domain. | First tick can occur less than 1 ms after start. Counting N ticks alone does not guarantee N full milliseconds; alignment or an extra timing rule is needed. Deferred. |
| Divided internal clock | A slower clock signal. | Adds clock-domain/clock-routing obligations without a current application need. Not proposed. |

The block name “Timer / Oscillator” does not require a physical oscillator or a new internal clock. If periodic behavior is adopted, its output is a clock-enable event in the existing domain.

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
| Optional periodic example | 100 Hz; 10 ms; 500,000 cycles | A-10: possible status/sampling example only. F-11 remains optional until a consumer is identified. This cadence does not gate the proposed debounce. |
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

For storage of the inclusive integer range `0…N_max`, the required capacity is `max(1, ceil(log2(N_max + 1)))` bits. A later architecture may choose a different count representation but must preserve the same external boundaries. Elaboration constraints: `TIMER_WIDTH >= 1`, `SENSOR_CHANNELS >= 1`, and `DEBOUNCE_CYCLES >= 1`. Zero debounce is an invalid configuration, unlike the explicitly normalized runtime timer zero value.

With actual clock frequency `f_actual`, the physical interval is `N / f_actual`. For an agreed frequency range `[f_min, f_max]`, its bounds are `[N / f_max, N / f_min]`. No numeric oscillator error or accuracy percentage is known. The rounding guarantee above is relative to the configured frequency and does not guarantee a minimum physical delay under a faster actual clock.

## 4. One-shot edge contract

These are proposed observable semantics, not an FSM implementation. All sampled conditions refer to inputs and status **immediately before** a rising edge; output changes described below occur immediately after that edge.

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
- At startup, validity is low and the input must qualify for the complete interval, even if its value equals the zero reset output. Reset-filled synchronizer stages must not count as fresh sensor observations. Architecture must specify pipeline startup gating and its exact latency before RTL.
- Independent channels can update on different edges; per-channel qualification provides no atomic multi-bit word guarantee.

This rejects short **observed** disturbances. RTL simulation cannot guarantee rejection of every analog glitch between sampling edges or prove metastability performance. A synchronizer's acquisition latency precedes the debounce interval, and a registered consumer normally adds a later observation edge. Document that latency when the pipeline is fixed; do not silently include it in the nominal 20 ms or claim a physical maximum without evidence.

## 6. Protection-window budget and ownership

PULSE exposes the one-shot duration and elapsed event; GUARDIAN starts/cancels it and determines the application consequence. The trigger event (pump request versus effective pump enable), expected qualified response, and reset/recovery behavior remain Q-04/Q-06. No dry-run threshold has been validated.

The integration budget must include the expected process response plus synchronization, debounce, GUARDIAN observation/decision latency, and an agreed margin. Starting a timer on a pump request also includes any delay before effective pump enable. A response that physically occurs just before a deadline may be reported after it because it is still being qualified.

With the proposed PULSE priority, cancel already high before the expiration edge suppresses `timer_done`. A GUARDIAN cancel derived from a newly registered sensor output cannot be assumed to act retroactively on that same edge. If GUARDIAN observes a qualified response and a completion event together, its decision priority must be agreed explicitly. The provisional PULSE contract makes both observations deterministic without choosing the pump/fault policy.

The 5 s example is an application configuration value, not a second timer feature or a hardwired protection limit. One timer can measure only one external interval at a time; overlapping pump-start delays and monitoring windows require further requirements review.

## 7. Optional periodic event proposal

Only if F-11 is adopted: latch the period on the first edge with both global enable and `periodic_enable` asserted following a disabled interval. Treat that as `p0`; normalize a period setting of zero to one cycle. Produce the first registered `periodic_tick` after P full intervals at `pP`, then at `p2P`, etc. Configuration remains captured until periodic operation is disabled and enabled again.

The event is one clock interval wide for P > 1. P = 1 requests an event on every active clock edge after startup, so the level remains high across consecutive event cycles; a low gap is not promised. Consumers must use it as a clock enable. Global reset/disable or `periodic_enable = 0` clears it and restarts phase. `timer_start`/`timer_cancel` do not affect periodic timing.

At the illustrative P = 500,000 and 50 MHz, event spacing is 10 ms and frequency is 100 Hz. This is an optional example, not a confirmed sampling requirement.

## 8. Later verification and present evidence

Unit simulations may retain the illustrative clock but use small elaboration/configuration counts, clearly labeled accelerated fixtures. For example, four debounce cycles and a 32-cycle window mean 80 ns and 640 ns at 50 MHz, not 20 ms and 5 s. Use a reduced timer width to exercise every count and its maximum, then add selected default-width/default-duration checks. No testbench has been implemented in this phase.

The clock period, example cycle counts, maximum timer duration, and required example widths above were independently recalculated in PowerShell during this documentation pass. These are arithmetic checks, not simulator or synthesis results. Final edge behavior, pipeline latency, and application response budgets remain subject to architecture review and later self-checking simulation.
