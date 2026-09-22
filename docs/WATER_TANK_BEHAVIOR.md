# Digital water-tank demonstration behavior

Status: **PROVISIONAL — engineering simulation assumptions, not another team's finalized implementation.** Written before the application RTL/model. These choices make the required application tests concrete while Q-01 through Q-08 remain open for real integration.

Implementation language: Verilog HDL

Updated 2026-09-22 for the OSC-CONTRACT-1 integration: the periodic extension is explicitly disabled in this application. The existing behavior and A-G test intent below are unchanged.

## 1. Ownership and assumptions

`src/application/water_tank_controller.v` is a synthesizable demonstration of GUARDIAN policy around PULSE. It is replaceable when GUARDIAN supplies an agreed interface. Simulation-only tank, pump, and noise models are `.v` files in `tb/models`; they model digital cause/effect and make no hydraulic, electrical, mechanical, or hardware safety claim. The Verilog-2001 conversion preserves all application assumptions and model behavior below.

The controller's PULSE instance ties `periodic_enable` low, drives zero `cfg_period_cycles`, and leaves `periodic_tick` unused. It introduces no periodic sampling, pump timing, recovery, or additional protection window. Recurring-event consumption is demonstrated separately in the periodic unit bench, and enabled concurrency is checked at the reusable PULSE top. [OSC-CONTRACT-1](OSCILLATOR_CONTRACT.md) does not assert an agreed external application consumer.

| ID | Demonstration assumption | Reason / implication |
| --- | --- | --- |
| APP-01 | Two active-high threshold predicates: bit 0 `above_low`, bit 1 `full`. | Maps three useful levels without pretending to know SENTINEL's real encoding. Both are independently synchronized/debounced by PULSE. |
| APP-02 | Model level is an integer 0…100; `above_low` means level >= 25 and `full` means level >= 90. | Unitless scenario fixture with room for LOW → MID → FULL progression; not tank dimensions or sensor calibration. |
| APP-03 | Start pump and monitoring together when all qualified inputs are valid and indicate LOW. Keep filling through MID; stop on FULL. | Demonstrates hysteresis through controller state, without an extra pump-start delay. |
| APP-04 | Expected initial response is a qualified `above_low = 1` within the configured window. | Exercises absence-of-response timing. It does not monitor later flow loss after MID or prove dry-run causation. |
| APP-05 | On expiry without response, stop pump and latch suspected dry-run until `fault_clear` or reset. A clear returns to IDLE; if LOW still qualifies, the next eligible edge restarts filling. | Explicit manual-recovery fixture; no timed automatic retry policy. |
| APP-06 | When a qualified response and a done event are observed on the same controller edge, response wins. FULL stops filling even on that edge. | Resolves a required race deterministically. PULSE's cancel priority remains unchanged. |
| APP-07 | Invalid/unqualified inputs inhibit a new start. Loss of validity or contradictory qualified thresholds while filling returns to IDLE and turns pump off; it does not latch a dry-run fault. | Prevents interpreting initialization/incoherent values as a valid level. This handling is a local demonstration assumption. A latched fault remains latched until clear/reset. |
| APP-08 | A running pump produces model flow iff source water is available. No startup lag; level changes only on named model steps. | Keeps the digital application deterministic and understandable. Model step rate/fill increment are explicit test parameters. |

## 2. Threshold representation

Use `sensor_in[1:0] = {full, above_low}` at the PULSE boundary.

| Qualified bits | Meaning | Permitted controller action |
| --- | --- | --- |
| `00` | LOW | Start from IDLE; continue an already started fill. |
| `01` | MID / NORMAL | Do not start from IDLE; confirm response and continue an existing fill. |
| `11` | FULL | Turn pump off on the controller observation edge. |
| `10` | Contradictory thresholds | Inhibit/stop filling under APP-07. |

`sensor_valid` must be `11` before interpreting the combined value. Independent validity does not imply an atomic coherent measurement; the explicit contradictory-code rule only handles that one observable inconsistency, not every possible transient combination. No analog value is fed into PULSE.

## 3. Controller states and priorities

All controller state changes occur at rising `clk`. `pump_enable` is high only in WAIT_RESPONSE/FILLING; `dry_run_detected` and `protection_active` are high only in PROTECTED. The latter two are separate named observability outputs with the same meaning in this small demonstration. Reset/disable returns to IDLE with pump and fault indications low on the sampling edge. Controls are synchronous.

The state encodings are two-bit `localparam` values: IDLE `00`, WAIT_RESPONSE `01`, FILLING `10`, and PROTECTED `11`. `reg [1:0] state` is updated in `always @(posedge clk)`. An `always @(*)` block assigns `next_state`, `timer_start`, and `timer_cancel`, with defaults on every path. Status outputs and child-driven connections are `wire` nets. This preserves the same-edge pump/start relationship and all priorities below.

| Old state | Condition, in priority order after reset/disable | Next state / timer action |
| --- | --- | --- |
| IDLE | All inputs valid, code LOW | WAIT_RESPONSE; assert one-cycle start and capture `cfg_protection_cycles`. Pump becomes enabled on that same edge. |
| IDLE | Otherwise | Stay IDLE, pump off; no start. |
| WAIT_RESPONSE | Input validity lost or contradictory code | IDLE; cancel timer. |
| WAIT_RESPONSE | FULL | IDLE; cancel timer. |
| WAIT_RESPONSE | MID | FILLING; cancel timer; pump remains on. |
| WAIT_RESPONSE | `timer_done` with no accepted response | PROTECTED; pump off. |
| WAIT_RESPONSE | Otherwise | Stay; one-shot progresses independently of sensor chatter. |
| FILLING | Invalid/unqualified or FULL | IDLE; pump off. |
| FILLING | Otherwise | Stay FILLING. No second response window is running. |
| PROTECTED | `fault_clear = 1` | IDLE; recovery requires a subsequent eligible start edge. |
| PROTECTED | Otherwise | Stay PROTECTED, regardless of sensor changes. |

`fault_clear` in other states is ignored. Timer cancellation is asserted for observed response/invalidity in WAIT_RESPONSE and may remain asserted in FILLING/PROTECTED; it must not be asserted on the IDLE edge that starts a window. The top-level PULSE global enable/reset follows the application controls. No external raw sensor or noise signal directly drives pump state.

An expiry event is registered by PULSE at N cycles after start. The controller observes it at the following rising edge and turns the pump off then if no response wins. Thus the command-to-stop interval is N+1 clock periods for an uninterrupted timeout scenario. The response qualification pipeline similarly adds observation latency; see [timing](PULSE_TIMING_SPEC.md).

## 4. Model and test requirements

`pump_model` exposes commanded running state and source-dependent flow. `water_tank_model` integrates named fill/drain steps at a configured step period, saturates at 0/100, and resets to a configured initial level. `sensor_model` converts level to thresholds and supports a test-controlled noise mask. These models are verification assets, excluded from the synthesis file list.

All models and `tb/water_tank_system_tb.v` use Verilog-2001 syntax. The tank model's `output integer level` retains its signed 32-bit arithmetic; the sensor model receives the same value through `input wire signed [31:0] level`. Testbench checks preserve false/X/Z failure detection using case inequality, packed 256-byte diagnostic messages, `$display`, and `$stop`, with failure enforced by the simulation runner.

The self-checking application testbench must demonstrate:

| Case | Stimulus | Expected observation |
| --- | --- | --- |
| A | Source available; LOW tank fills through MID to FULL | Validated LOW starts pumping; MID cancels window; FULL stops; no dry-run. |
| B | Noise on level predicates shorter than D observed cycles | Qualified state and pump decision reject those disturbances. |
| C | Source unavailable while starting from LOW | No expected response; window completes, pump stops, protection latches. |
| D | Restore source and assert fault clear | Fault releases, fresh start is possible, normal fill resumes. No spontaneous retry before clear. |
| E | Reset at startup, during active fill, and during protection | Documented IDLE/reset outputs; fresh qualification required. |
| F | Response/done on the same observation edge | Response takes priority under APP-06. |
| G | Contradictory qualified thresholds and disable/re-enable | APP-07 inhibits/stops pumping; disable resets; fresh qualification after enable. |

Use accelerated counts to run these scenarios quickly and label them as simulation parameters. The reusable one-shot and debounce tests separately cover their recorded nominal/default-duration cases and documented unrun long-duration limits. The A-G expected behaviors above retain their original test intent; actual current results are in [OSCILLATOR_COMPLETION.md](OSCILLATOR_COMPLETION.md). The oscillator integration reruns the existing application suite without adding new water-tank behavior or claiming new timer-duration tests.
