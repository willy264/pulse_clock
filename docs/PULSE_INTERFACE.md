# PULSE interface specification

Status: **PROVISIONAL — pending agreement with integration team.**

Prepared: 2026-09-10; updated 2026-09-22 for [OSC-CONTRACT-1](OSCILLATOR_CONTRACT.md). Scope: the PULSE-side working contract. Other-team interfaces remain provisional.

## 1. Scope and design choices

The master prompt's example `pulse_top` interface is illustrative. No existing SENTINEL, GUARDIAN, VOICE, or ANCHOR ports were found. The following names, widths, controls, and defaults are engineering proposals under A-01 through A-12 in [requirements](PULSE_REQUIREMENTS.md). They are not another team's published interfaces.

The external boundary has one independent one-shot, a bank of sensor qualification channels, and an independent periodic event generator. This supports concurrent sensor validation, protection timing, and recurring events. Module partitioning, downcounters, startup pipelines, and states are defined in [architecture](PULSE_ARCHITECTURE.md) and [state machines](PULSE_STATE_MACHINES.md). The user's oscillator-completion request adopts the periodic-tick working contract without claiming an external consumer or supervisor approval.

| Choice | Proposed behavior | Alternative and implication |
| --- | --- | --- |
| Timer configuration | Runtime cycle-count input captured on accepted start. | A fixed elaboration parameter is simpler but cannot change windows between operations. |
| Debounce configuration | Common elaboration-time cycle-count parameter. | Per-channel/runtime intervals add ports and update semantics; no such requirement is confirmed. |
| Completion | One-cycle `timer_done` plus level `timer_busy`. | Sticky done with acknowledgement serves slower/asynchronous consumers but requires more handshake state. |
| End a monitoring window | Dedicated `timer_cancel`. | Reusing global disable would discard valid sensor readings; cancellation avoids that coupling. |
| Input representation | Independent Boolean channels, with validity per channel. | An encoded LOW/MID/HIGH word needs coherent transport and a separately agreed representation. |
| Periodic behavior | Separate clock-enable controls/output under OSC-CONTRACT-1; capture on first jointly enabled edge and retain across reloads. | Multiplexing timer mode would prevent independent operation. A square-wave alternative needs different timing semantics and is outside the selected working contract. |

No PULSE port directly drives a pump or declares a dry-run fault. PULSE does not interpret sensor polarity, threshold order, impossible combinations, or recovery rules.

## 2. Parameters and configuration ownership

| Name | Form / initial value | Valid range and purpose | Proposed owner |
| --- | --- | --- | --- |
| `TIMER_WIDTH` | Elaboration parameter, 32 | Positive integer; width of unsigned runtime cycle counts. | PULSE integrator. |
| `SENSOR_CHANNELS` | Elaboration parameter, 2 | Positive integer; number of independent Boolean qualification channels. Two is an illustrative application choice, not an agreed SENTINEL width. | SENTINEL/integration agreement. |
| `DEBOUNCE_CYCLES` | Elaboration parameter, 1,000,000 | Positive integer; number of full observed stability intervals; common to all channels and both directions. | Sensor/application timing agreement. |
| `PERIOD_WIDTH` | Elaboration parameter, 32; appended after the existing three `pulse_top` parameters | Positive integer; width of unsigned periodic configuration and retained period/count, independent of `TIMER_WIDTH`. | PULSE integrator. |
| `CLOCK_FREQ_HZ` | Integration/testbench timing metadata, illustrative 50,000,000 | Positive frequency of externally supplied `clk`; used to calculate cycle counts. Not a runtime port or an instruction to generate a clock. | Clock/integration owner. |

The [timing specification](PULSE_TIMING_SPEC.md) defines ranges and arithmetic. An architecture may carry frequency as a parameter if it actually derives constants from it; it should not introduce unused parameters merely to match an example.

## 3. Common timing convention

All ports except `sensor_in` belong to the `clk` domain. Control/configuration inputs must meet setup/hold requirements around rising edges. Registered outputs update after the edge; a downstream register consumes their updated values on a later edge. `sensor_in` is provisionally allowed to be asynchronous under section 6.

Reset is proposed as active-high and synchronous. The system must supply an asserted reset spanning a rising edge before relying on outputs. No known output value is promised before that reset edge. Asynchronous reset conditioning is an integration responsibility if required.

For input ports, “reset obligation” describes what the producer must provide; PULSE cannot reset an externally driven input. Controls other than reset are ignored while reset is sampled high. Producers should drive known 0/1 logic during operation; X/Z stimuli are verification/error cases, not an additional valid level encoding.

## 4. Timer, sensor, and common ports

`W = TIMER_WIDTH`; `S = SENSOR_CHANNELS`; `R = PERIOD_WIDTH`. Directions are relative to PULSE. Names/behavior form the working local contract; other-team endpoint agreements remain provisional. The three periodic ports in section 7 are also present on `pulse_top`.

| Port | Direction / width | Meaning / active level | Reset state or producer obligation | Timing / valid conditions | Proposed producer → consumer |
| --- | --- | --- | --- | --- | --- |
| `clk` | Input / 1 | External system clock; rising edge active. | Must run so synchronous reset can be sampled. | Single functional domain; illustrative 50 MHz, not a fixed requirement. | System clock/integration → all PULSE sequential logic. |
| `reset` | Input / 1 | Active-high synchronous reset. | Producer asserts across at least one rising edge; other controls ignored at that edge. | Highest priority; clear timer, sensor output/validity, and periodic phase/output on sampling edge. | System reset/integration → PULSE. |
| `enable` | Input / 1 | High permits normal operation; low aborts, clears qualification, and clears periodic phase. | Producer may hold low through reset; reset has priority regardless. | Sample every rising edge. Low clears busy/done, sensor output/validity, and periodic output/phase. High restarts qualification, permits fresh starts, and captures periodic configuration if locally enabled. No pause/resume. | Integration run control → PULSE. |
| `timer_start` | Input / 1 | Active-high one-cycle start request. | Producer normally drives 0; ignored under reset. | Accepted only if enabled, not cancelled, and old busy is 0. No queue; ignored while busy, including expiry edge. | GUARDIAN or reusable-timer caller → PULSE one-shot. |
| `timer_cancel` | Input / 1 | Active-high abort/inhibit for the one-shot only. | Producer normally drives 0; ignored under reset. | Clears busy/done on sampling edge; outranks expiry and start. May be held high. Does not change debounce or periodic phase. | GUARDIAN or reusable-timer caller → PULSE one-shot. |
| `cfg_timer_cycles` | Input / W, unsigned | Requested elapsed system-clock cycles; no active polarity. | Externally owned; ignored during reset. Must be known and in range on accepted start. | Captured at accepted start; zero maps to one cycle. Changes while busy affect only a future start. | GUARDIAN/integration configuration → PULSE one-shot. |
| `timer_busy` | Output / 1 | High means one-shot is in progress. | 0 after reset/disable/cancel sampling edge. | Asserts after accepted start; clears after expiry or abort. Indicates availability for a later sampled start. | PULSE → GUARDIAN/caller; optional status aggregation. |
| `timer_done` | Output / 1 | Active-high elapsed-window event. | 0 after reset/disable/cancel sampling edge. | High for one clock interval on normal completion; busy is then 0. No acknowledgement port. Consumers must capture it synchronously. | PULSE → GUARDIAN/caller. |
| `sensor_in` | Input / S | Independent Boolean source signals; 1/0 meanings defined externally. | No required physical level; ignored for validity until startup qualification completes. | Provisional asynchronous inputs; synchronize before qualification. No atomic encoded-word guarantee. | SENTINEL or integration adapter → PULSE sensor input boundary. |
| `sensor_debounced` | Output / S | Last qualified value for each channel; preserves logical polarity. | All zero after reset/disable; not a measured water level while corresponding valid bit is 0. | Changes only after that channel completes qualification, except reset/disable clearing. Held through rejected noise. | PULSE → GUARDIAN; optional qualified-status aggregation for VOICE. |
| `sensor_valid` | Output / S | Bit high means that channel has qualified at least once since reset/disable. | All zero after reset/disable. | Set with initial accepted value; held high through later candidate/noise intervals until reset/disable. Does not mean raw input presently matches output. | PULSE → GUARDIAN/integration status consumer. |

There is deliberately no public internal `counter` port. Later testbenches/wave configurations can inspect appropriate internal state without turning its implementation into an integration dependency.

## 5. Handshake and boundary behavior

The one-shot interface uses synchronous control strobes rather than a bus or an acknowledgement protocol. Its priority remains **reset > disable > timer_cancel > active counting/expiry > idle start**. The periodic generator has its own local enable and priority in section 7.

If a start with configuration N is accepted at `e0`, the timer becomes busy after `e0` and completes at `e(max(1,N))`. Configuration is frozen for that operation. The elapsed event is high until the next edge. The [timing specification](PULSE_TIMING_SPEC.md) contains the edge table and minimum/maximum boundaries.

A caller checks old busy low and presents a one-cycle start strobe and stable configuration. A start presented on the existing operation's expiration edge is ignored because old busy is still high. The next edge can accept a start. Holding start high through a later idle edge can trigger another operation; this proposal does not add start edge detection. Cancellation held high inhibits all starts and suppresses completion, including when cancellation coincides with expiry.

Global disable clears timer, sensor, and periodic state on a sampling edge. Use `timer_cancel` when an expected response ends monitoring while sensors should remain qualified and periodic timing should continue. Local `periodic_enable = 0` clears only periodic state. If the application does not need global disable, its integration wrapper can tie `enable` high.

GUARDIAN must decide the meaning of a timeout and how to handle simultaneous response/expiry observations. PULSE's cancellation priority only applies when cancel is already asserted before its sampling edge. It does not let a later GUARDIAN decision cancel a past event.

## 6. Sensor and clock-domain boundary

**PROVISIONAL — pending agreement with SENTINEL and integration.** A-06 proposes two synchronization stages per independent input bit inside the PULSE boundary, followed by qualification in the `clk` domain. If SENTINEL instead guarantees signals already registered in the same domain, revise ownership and latency together before removing or duplicating that boundary.

Synchronization registers reduce the risk of metastability propagation; the number of stages must eventually be justified using the chosen clock/device and timing analysis. This general rationale is supported by the vendor's [Design Recommendations: Metastability Analysis](https://docs.altera.com/r/docs/683323/18.1/intel-quartus-prime-standard-edition-user-guide-design-recommendations/metastability-analysis-in-the-intel-quartus-prime-software). That reference is design guidance, not evidence that this project has passed CDC or hardware analysis, nor a compatibility claim for the locally installed Quartus version.

The debounce observes synchronized digital samples. On the first fresh candidate sample, start a full `DEBOUNCE_CYCLES` interval; accept only if the candidate remains identical through the ending observation. A change on that ending edge restarts qualification instead. A two-stage readiness pipeline excludes reset-filled samples; first observation is two clock periods after the first enabled capture edge, followed by the full qualification interval.

The S bits do not constitute an agreed encoding for LOW/MID/HIGH. Independent synchronizers and debounce channels can produce values from different observation times. If SENTINEL exports an encoded word, the teams must agree coherent transfer and validation; simply synchronizing each bit is insufficient to promise word coherence. Likewise, all bits of `sensor_valid` high means each has qualified, not that their combined reading is atomic or physically consistent. GUARDIAN/SENTINEL own combination checks after a representation is agreed.

The timer and periodic controls/configuration are assumed synchronous. Sending them from another clock domain would require a separate agreed handshake; a wide configuration value cannot be made coherent by casually adding per-bit synchronizers.

## 7. Periodic event ports: OSC-CONTRACT-1

F-11 is included in the current oscillator-completion scope. These ports belong to the working `pulse_top` interface and to standalone `pulse_periodic` alongside common `clk`, `reset`, and `enable`. The function progresses independently of the one-shot and debounce. A unit-bench synchronous event counter demonstrates consumption; the water-tank adapter ties local enable low, supplies zero configuration, and leaves tick unused. No external application consumer is claimed.

| Port | Direction / width | Meaning / active level | Reset state or producer obligation | Timing / valid conditions | Proposed producer → consumer |
| --- | --- | --- | --- | --- | --- |
| `periodic_enable` | Input / 1 | High requests periodic operation while global enable is high. | Producer supplies known value; normally 0 during reset. | First jointly enabled edge captures period and starts phase; sampled low clears event and phase, including on expiry. Does not affect timer/debounce. | Integration or standalone test caller → PULSE periodic generator. |
| `cfg_period_cycles` | Input / R, unsigned | Period in system-clock cycles; no active polarity. | Externally owned; ignored under reset/disable. Known/in-range at capture. | Captured on first jointly enabled edge after inactivity. Zero maps to one; active changes are ignored across reloads and apply only after sampled clear and restart. | Integration or standalone test caller → periodic capture. |
| `periodic_tick` | Output / 1 | Registered high event/clock enable; never an internal clock. | 0 after reset/global-disable/periodic-disable sampling edge. | Capture at p0; first high after pP, then p2P/p3P. One-cycle high for P > 1; consecutive high cycles from p1 for P = 1. A separate sequential consumer first observes it at p(P+1). | PULSE → synchronous event-counter demonstration; external consumer remains Q-08. |

The periodic priority is **sampled reset/global disable/local disable > inactive capture > active expiry/reload > active decrement**. A clear on expiry suppresses the new event; a later clear does not undo an earlier high interval. There is no pause, acknowledgement, or live period update. For P = 1 a consumer must count high samples at `posedge clk`, not just rising transitions of the tick. See [OSC-CONTRACT-1](OSCILLATOR_CONTRACT.md) for worked P = 3/P = 1 schedules and example rates.

No toggle clock, frequency bus, interrupt controller, sticky event register, or periodic completion acknowledgement is included. If a slower or asynchronous VOICE interface needs retained events, its adapter must capture them under a separately agreed contract.

## 8. Integration responsibility map and review checklist

| Connection | What this proposal offers | Agreement still required |
| --- | --- | --- |
| SENTINEL → PULSE | S independent Boolean `sensor_in` channels and proposed synchronization ownership. | Meaning, polarity, S, domain/coherence, noise budget, and responsibility for impossible combinations (Q-02/Q-03). |
| GUARDIAN → PULSE | Synchronous start/cancel and runtime duration; optional run enable via integration. | Monitoring trigger, expected response, max interval, number of simultaneous windows, handshake acceptance (Q-04/Q-05/Q-07). |
| PULSE → GUARDIAN | Debounced values/validity, busy, one-cycle elapsed event. | Invalid-startup handling, simultaneous-event priority, pump/reset/recovery decisions (Q-06/Q-07). |
| PULSE → VOICE | Potential qualified status through an adapter and available periodic enable events. | Whether a direct connection exists, status/event retention needs, cadence, and domain (Q-08); no direct consumer is claimed. |
| Integration/possible ANCHOR → PULSE | Clock and synchronous reset inputs. | Actual source ownership, frequency/tolerance, reset conditioning (Q-01). No ANCHOR implementation is assumed. |

Final agreements are **BLOCKED / REQUIRES TEAM INPUT**; the named owners are proposed integration responsibilities, not evidence of another team's acceptance.

Internal review checks the clock/reset and synchronization boundary; independent timer/period widths; zero behavior and control priority; startup validity and full-interval debounce; periodic capture/reload and consumer latency; and concurrent operation. The periodic ports are part of OSC-CONTRACT-1. Every top-level instantiation must connect them explicitly. The application adapter disables the feature and retains the existing documented pump/protection behavior.
