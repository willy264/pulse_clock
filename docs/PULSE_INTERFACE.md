# PULSE initial interface specification

Status: **PROVISIONAL — pending agreement with integration team.**

Prepared: 2026-09-10. Scope: a proposed PULSE-side contract for review, with no module declaration or RTL implementation.

## 1. Scope and design choices

The master prompt's example `pulse_top` interface is illustrative. No existing SENTINEL, GUARDIAN, VOICE, or ANCHOR ports were found. The following names, widths, controls, and defaults are engineering proposals under A-01 through A-12 in [requirements](PULSE_REQUIREMENTS.md). They are not another team's published interfaces.

The candidate external boundary has one independent one-shot and a bank of sensor qualification channels. This supports concurrent sensor validation and protection timing. Module partitioning, counter implementation, internal pipelines, and state machines are deferred to the architecture phase.

| Choice | Proposed behavior | Alternative and implication |
| --- | --- | --- |
| Timer configuration | Runtime cycle-count input captured on accepted start. | A fixed elaboration parameter is simpler but cannot change windows between operations. |
| Debounce configuration | Common elaboration-time cycle-count parameter. | Per-channel/runtime intervals add ports and update semantics; no such requirement is confirmed. |
| Completion | One-cycle `timer_done` plus level `timer_busy`. | Sticky done with acknowledgement serves slower/asynchronous consumers but requires more handshake state. |
| End a monitoring window | Dedicated `timer_cancel`. | Reusing global disable would discard valid sensor readings; cancellation avoids that coupling. |
| Input representation | Independent Boolean channels, with validity per channel. | An encoded LOW/MID/HIGH word needs coherent transport and a separately agreed representation. |
| Periodic behavior | Separate optional clock-enable controls/output, if justified. | Multiplexing timer mode would prevent independent periodic and one-shot progress. Omission is valid while no consumer is identified. |

No PULSE port directly drives a pump or declares a dry-run fault. PULSE does not interpret sensor polarity, threshold order, impossible combinations, or recovery rules.

## 2. Parameters and configuration ownership

| Name | Form / initial value | Valid range and purpose | Proposed owner |
| --- | --- | --- | --- |
| `TIMER_WIDTH` | Elaboration parameter, 32 | Positive integer; width of unsigned runtime cycle counts. | PULSE integrator. |
| `SENSOR_CHANNELS` | Elaboration parameter, 2 | Positive integer; number of independent Boolean qualification channels. Two is an illustrative application choice, not an agreed SENTINEL width. | SENTINEL/integration agreement. |
| `DEBOUNCE_CYCLES` | Elaboration parameter, 1,000,000 | Positive integer; number of full observed stability intervals; common to all channels and both directions. | Sensor/application timing agreement. |
| `CLOCK_FREQ_HZ` | Integration/testbench timing metadata, illustrative 50,000,000 | Positive frequency of externally supplied `clk`; used to calculate cycle counts. Not a runtime port or an instruction to generate a clock. | Clock/integration owner. |

The [timing specification](PULSE_TIMING_SPEC.md) defines ranges and arithmetic. An architecture may carry frequency as a parameter if it actually derives constants from it; it should not introduce unused parameters merely to match an example.

## 3. Common timing convention

All ports except `sensor_in` belong to the `clk` domain. Control/configuration inputs must meet setup/hold requirements around rising edges. Registered outputs update after the edge; a downstream register consumes their updated values on a later edge. `sensor_in` is provisionally allowed to be asynchronous under section 6.

Reset is proposed as active-high and synchronous. The system must supply an asserted reset spanning a rising edge before relying on outputs. No known output value is promised before that reset edge. Asynchronous reset conditioning is an integration responsibility if required.

For input ports, “reset obligation” describes what the producer must provide; PULSE cannot reset an externally driven input. Controls other than reset are ignored while reset is sampled high. Producers should drive known 0/1 logic during operation; X/Z stimuli are verification/error cases, not an additional valid level encoding.

## 4. Proposed core ports

`W = TIMER_WIDTH`; `S = SENSOR_CHANNELS`. Directions are relative to PULSE. Every signal and its endpoints below is provisional.

| Port | Direction / width | Meaning / active level | Reset state or producer obligation | Timing / valid conditions | Proposed producer → consumer |
| --- | --- | --- | --- | --- | --- |
| `clk` | Input / 1 | External system clock; rising edge active. | Must run so synchronous reset can be sampled. | Single functional domain; illustrative 50 MHz, not a fixed requirement. | System clock/integration → all PULSE sequential logic. |
| `reset` | Input / 1 | Active-high synchronous reset. | Producer asserts across at least one rising edge; other controls ignored at that edge. | Highest priority; clear timer and sensor output/validity on sampling edge. | System reset/integration → PULSE. |
| `enable` | Input / 1 | High permits normal operation; low aborts and clears qualification. | Producer may hold low through reset; reset has priority regardless. | Sample every rising edge. Low clears busy/done and sensor output/validity; high restarts qualification and permits fresh starts. No pause/resume. | Integration run control → PULSE. |
| `timer_start` | Input / 1 | Active-high one-cycle start request. | Producer normally drives 0; ignored under reset. | Accepted only if enabled, not cancelled, and old busy is 0. No queue; ignored while busy, including expiry edge. | GUARDIAN or reusable-timer caller → PULSE one-shot. |
| `timer_cancel` | Input / 1 | Active-high abort/inhibit for the one-shot only. | Producer normally drives 0; ignored under reset. | Clears busy/done on sampling edge; outranks expiry and start. May be held high. Does not change debounce. | GUARDIAN or reusable-timer caller → PULSE one-shot. |
| `cfg_timer_cycles` | Input / W, unsigned | Requested elapsed system-clock cycles; no active polarity. | Externally owned; ignored during reset. Must be known and in range on accepted start. | Captured at accepted start; zero maps to one cycle. Changes while busy affect only a future start. | GUARDIAN/integration configuration → PULSE one-shot. |
| `timer_busy` | Output / 1 | High means one-shot is in progress. | 0 after reset/disable/cancel sampling edge. | Asserts after accepted start; clears after expiry or abort. Indicates availability for a later sampled start. | PULSE → GUARDIAN/caller; optional status aggregation. |
| `timer_done` | Output / 1 | Active-high elapsed-window event. | 0 after reset/disable/cancel sampling edge. | High for one clock interval on normal completion; busy is then 0. No acknowledgement port. Consumers must capture it synchronously. | PULSE → GUARDIAN/caller. |
| `sensor_in` | Input / S | Independent Boolean source signals; 1/0 meanings defined externally. | No required physical level; ignored for validity until startup qualification completes. | Provisional asynchronous inputs; synchronize before qualification. No atomic encoded-word guarantee. | SENTINEL or integration adapter → PULSE sensor input boundary. |
| `sensor_debounced` | Output / S | Last qualified value for each channel; preserves logical polarity. | All zero after reset/disable; not a measured water level while corresponding valid bit is 0. | Changes only after that channel completes qualification, except reset/disable clearing. Held through rejected noise. | PULSE → GUARDIAN; optional qualified-status aggregation for VOICE. |
| `sensor_valid` | Output / S | Bit high means that channel has qualified at least once since reset/disable. | All zero after reset/disable. | Set with initial accepted value; held high through later candidate/noise intervals until reset/disable. Does not mean raw input presently matches output. | PULSE → GUARDIAN/integration status consumer. |

There is deliberately no public internal `counter` port. Later testbenches/wave configurations can inspect appropriate internal state without turning its implementation into an integration dependency.

## 5. Handshake and boundary behavior

The interface uses synchronous control strobes rather than a bus or an acknowledgement protocol. At each edge apply **reset > disable > timer_cancel > active counting/expiry > idle start**.

If a start with configuration N is accepted at `e0`, the timer becomes busy after `e0` and completes at `e(max(1,N))`. Configuration is frozen for that operation. The elapsed event is high until the next edge. The [timing specification](PULSE_TIMING_SPEC.md) contains the edge table and minimum/maximum boundaries.

A caller checks old busy low and presents a one-cycle start strobe and stable configuration. A start presented on the existing operation's expiration edge is ignored because old busy is still high. The next edge can accept a start. Holding start high through a later idle edge can trigger another operation; this proposal does not add start edge detection. Cancellation held high inhibits all starts and suppresses completion, including when cancellation coincides with expiry.

Global disable clears both timer and sensor state on a sampling edge. Use `timer_cancel` when an expected response ends monitoring while sensors should remain qualified. If the application does not need global disable, its integration wrapper can tie `enable` high; the recommended interface is still reviewable without inventing a pause mode.

GUARDIAN must decide the meaning of a timeout and how to handle simultaneous response/expiry observations. PULSE's cancellation priority only applies when cancel is already asserted before its sampling edge. It does not let a later GUARDIAN decision cancel a past event.

## 6. Sensor and clock-domain boundary

**PROVISIONAL — pending agreement with SENTINEL and integration.** A-06 proposes two synchronization stages per independent input bit inside the PULSE boundary, followed by qualification in the `clk` domain. If SENTINEL instead guarantees signals already registered in the same domain, revise ownership and latency together before removing or duplicating that boundary.

Synchronization registers reduce the risk of metastability propagation; the number of stages must eventually be justified using the chosen clock/device and timing analysis. This general rationale is supported by the vendor's [Design Recommendations: Metastability Analysis](https://docs.altera.com/r/docs/683323/18.1/intel-quartus-prime-standard-edition-user-guide-design-recommendations/metastability-analysis-in-the-intel-quartus-prime-software). That reference is design guidance, not evidence that this project has passed CDC or hardware analysis, nor a compatibility claim for the locally installed Quartus version.

The debounce observes synchronized digital samples. On the first fresh candidate sample, start a full `DEBOUNCE_CYCLES` interval; accept only if the candidate remains identical through the ending observation. A change on that ending edge restarts qualification instead. Architecture must explicitly exclude reset-filled synchronizer values from startup qualification and account for acquisition latency.

The S bits do not constitute an agreed encoding for LOW/MID/HIGH. Independent synchronizers and debounce channels can produce values from different observation times. If SENTINEL exports an encoded word, the teams must agree coherent transfer and validation; simply synchronizing each bit is insufficient to promise word coherence. Likewise, all bits of `sensor_valid` high means each has qualified, not that their combined reading is atomic or physically consistent. GUARDIAN/SENTINEL own combination checks after a representation is agreed.

The timer controls and configuration are assumed synchronous. Sending them from another clock domain would require a separate agreed handshake; a wide configuration value cannot be made coherent by casually adding per-bit synchronizers.

## 7. Optional periodic extension

F-11 is **Optional**. These ports are candidates only and are not part of a committed baseline interface. They should be adopted together only after Q-08 identifies a consumer. The periodic function, if selected, progresses independently of the one-shot and debounce; the same global clock/reset/enable applies.

| Port | Direction / width | Meaning / active level | Reset state or producer obligation | Timing / valid conditions | Proposed producer → consumer |
| --- | --- | --- | --- | --- | --- |
| `periodic_enable` | Input / 1 | High requests periodic operation while global enable is high. | Producer normally drives 0 during reset. | First jointly enabled edge captures period and starts phase; sampled low clears event and phase. | Integration/optional sampling client → PULSE. |
| `cfg_period_cycles` | Input / W, unsigned | Period in system-clock cycles; no active polarity. | Externally owned; ignored under reset. Known/in-range when periodic operation starts. | Captured on first jointly enabled edge after inactivity. Zero maps to one; updates apply after disable/re-enable. | Integration/optional sampling client → PULSE. |
| `periodic_tick` | Output / 1 | High is an event/clock enable for a `clk` edge; never an internal clock. | 0 after reset/global-disable/periodic-disable sampling edge. | First event P full cycles after start; then every P cycles. One-cycle high for P > 1; consecutive high cycles for P = 1. | PULSE → identified synchronous sampling/status consumer, if any. |

No toggle clock, frequency bus, interrupt controller, sticky event register, or periodic completion acknowledgement is proposed. If a slower or asynchronous VOICE interface needs retained events, its adapter must capture them under a separately agreed contract.

## 8. Integration responsibility map and review checklist

| Connection | What this proposal offers | Agreement still required |
| --- | --- | --- |
| SENTINEL → PULSE | S independent Boolean `sensor_in` channels and proposed synchronization ownership. | Meaning, polarity, S, domain/coherence, noise budget, and responsibility for impossible combinations (Q-02/Q-03). |
| GUARDIAN → PULSE | Synchronous start/cancel and runtime duration; optional run enable via integration. | Monitoring trigger, expected response, max interval, number of simultaneous windows, handshake acceptance (Q-04/Q-05/Q-07). |
| PULSE → GUARDIAN | Debounced values/validity, busy, one-cycle elapsed event. | Invalid-startup handling, simultaneous-event priority, pump/reset/recovery decisions (Q-06/Q-07). |
| PULSE → VOICE | Potential qualified status through an adapter; optional periodic enable event. | Whether a direct connection exists, status/event retention needs, cadence, and domain (Q-08). |
| Integration/possible ANCHOR → PULSE | Clock and synchronous reset inputs. | Actual source ownership, frequency/tolerance, reset conditioning (Q-01). No ANCHOR implementation is assumed. |

Final agreements are **BLOCKED / REQUIRES TEAM INPUT**; the named owners are proposed integration responsibilities, not evidence of another team's acceptance.

Before architecture/RTL work, review the clock/reset and synchronization boundary; cycle units/ranges; zero behavior and control priority; startup validity and full-interval debounce; concurrent window/qualification behavior; and optional-periodic scope. The current four documents provide a concrete proposal for that review. No SystemVerilog file, state machine, or application behavior has been implemented or simulated.
