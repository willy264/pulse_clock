# PULSE requirements

Status: **Working baseline following the user's continuation on 2026-09-10.** External team agreements and numerical hardware assumptions remain provisional.

Prepared: 2026-09-10. Application: Water Tank Level & Dry-Run Protection Controller.

## 1. Scope and authority

The source is the user-supplied **MASTER PROJECT PROMPT**, particularly sections 1–5, 13–16, 20–24, and 37. No separate university project sheet, sensor specification, board specification, or other team's interface was present in the workspace. The first four-document deliverable stopped for review as section 37 requested. The user's subsequent instruction, “alright continue then,” permits continued design and implementation using the documented assumptions as the working baseline.

The eventual product is a reusable PULSE digital timing block, implemented in synthesizable SystemVerilog and demonstrated through ModelSim simulation of a water-tank controller. PULSE qualifies sensor transitions and measures intervals. GUARDIAN interprets those observations and owns pump control and protection policy. A timer expiry alone indicates elapsed time, not proof of a physical dry-run.

This document defines required capabilities and proposed measurable behavior. Internal architecture/FSM review precedes implementation. Continued project work does not finalize another team's contract or authorize physical implementation.

## 2. Classification

Priority and origin are separate:

| Label | Meaning |
| --- | --- |
| Required | Needed to satisfy the supplied project brief; implementation and verification occur in later phases. |
| Recommended | Proposed addition that makes the required behavior easier to integrate or verify; subject to review. |
| Optional | Include only when an application consumer or other agreed requirement justifies it. |
| Explicit origin | Stated in the master prompt. |
| Derived origin | Necessary consequence of a stated capability; not a quotation from the project sheet. |
| Assumption origin | A proposed engineering choice, not an external requirement. |

Approving a capability does not automatically approve its proposed port names or numerical defaults. The assumption register below is the common reference for [timing](PULSE_TIMING_SPEC.md) and [interface](PULSE_INTERFACE.md).

## 3. Functional requirements

| ID | Priority / origin | Requirement | Planned acceptance evidence |
| --- | --- | --- | --- |
| F-01 | Required / derived from synchronous timing and clock-domain rules | PULSE shall accept an external system clock. All functional timing shall have a defined relationship to that clock. | Edge-based checks of every output; clocking review. |
| F-02 | Required / derived from deterministic operation and reset tests | Reset shall establish known timer and sensor-status states and abort an active timing operation. | Reset when idle, counting, and qualifying a sensor. Polarity/style proposed in A-02. |
| F-03 | Required / explicit, §5A | PULSE shall provide a configurable one-shot interval and a completion indication. The interval's units, range, and configuration sampling point shall be documented. | Zero, minimum, representative, and maximum values; configuration changes during operation. |
| F-04 | Required / explicit, §5B | PULSE shall qualify sensor changes over a configured stability interval so shorter observed transitions do not immediately become accepted readings. | Noise rejection, stable rising/falling input, repeated changes, and a change on the expiration edge. |
| F-05 | Required / explicit, §5C | PULSE shall provide an elapsed-window indication usable by GUARDIAN to evaluate the absence of an expected water-level response. | Window completes without response; response can end monitoring under the agreed contract. |
| F-06 | Required / derived from F-04/F-05 | Sensor qualification shall remain operational during a protection window. Sensor chatter shall not change that window's deadline without an explicit timer control action. | Concurrent debounce and timer test with repeated noise. This requires independent progress, not a particular counter architecture. |
| F-07 | Recommended / assumption | Provide `timer_busy` so the caller can determine whether a new start can be accepted. | Busy agrees with start, completion, abort, and reset. |
| F-08 | Recommended / assumption | Provide an explicit cancellation control that ends a window without reporting expiry. | Cancellation before and exactly at expiry; cancellation must not reset sensor qualification. |
| F-09 | Recommended / assumption | Provide an operation enable with documented disable/re-enable behavior. | Disabled starts are ignored; disable aborts, rather than pauses, the timer; see A-05. |
| F-10 | Recommended / assumption | Distinguish an initialized sensor output from a qualified reading using per-channel validity status. | Output is invalid after reset/disable until startup qualification succeeds, even for an input equal to the reset value. |
| F-11 | Optional / conditional in §5D | Provide configurable periodic clock-enable events if a consumer needs periodic sampling or status updates. | If adopted, verify first event, spacing, disable/re-enable, and period changes. No consumer is confirmed yet. |
| F-12 | Recommended / assumption | Allow the number of independent Boolean sensor channels and their stability interval to be parameterized. | Each channel qualifies independently; changes on one do not reset another. Channel meanings remain provisional. |

The one-shot serves both reusable delays and the proposed protection window; a dedicated `dry_run_detected` output is not a PULSE requirement. One external timing operation at a time is the initial proposal. Multiple simultaneous application windows would require additional instances or a revised contract.

## 4. Non-functional and delivery requirements

| ID | Priority / origin | Requirement and later evidence |
| --- | --- | --- |
| N-01 | Required / explicit | Production RTL shall be synthesizable SystemVerilog. No functional `#delay`, file I/O, simulation clock generation, or `$display` logic. Separate testbench-only behavior. Review and later Quartus analysis provide evidence. |
| N-02 | Required / explicit | Use deterministic, modular RTL without inferred latches, multiple drivers, combinational feedback, accidental signed arithmetic, or unchecked width truncation. Review compiler/synthesis warnings. |
| N-03 | Required / explicit | Document clock-domain ownership. Prefer synchronous clock enables to unnecessary derived clocks. Debouncing shall not be presented as a replacement for synchronization. |
| N-04 | Required / explicit | Use named parameters/configuration values with units and valid ranges; justify defaults. Resource counts and counter widths shall follow those ranges. No area/power target has been supplied. |
| N-05 | Required / explicit | Specify timing accuracy, rounding, minimum/maximum delay, pulse width, reset behavior, and timer boundaries. Simulation shall check exact clock edges under the approved contract. |
| N-06 | Required / explicit | Keep the design understandable and reusable; add a module only for a meaningful function. No bus protocol, CPU, firmware, networking, or unrelated IP is required. |
| N-07 | Required / explicit | Use the existing ModelSim-Altera toolchain as the primary simulator. Later provide portable compile/run/wave scripts without repository-wide machine-specific executable paths. |
| N-08 | Required / explicit | Every major implemented module shall have a testbench. Use self-checking verification wherever practical and assertions where useful, with explicit pass/fail reporting and simulation timeout protection. Test unit, top-level integration, and application behavior. |
| N-09 | Required / explicit | Document provisional integration assumptions and obtain agreement before calling SENTINEL/GUARDIAN/VOICE/ANCHOR interfaces finalized. |
| N-10 | Required / explicit | In later phases maintain traceability, known issues, simulation evidence, and an honest final report. An unrun test shall never be reported as PASS. |
| N-11 | Required / explicit | Perform later Quartus RTL/synthesis checks and review warnings. Physical implementation is future work and shall not be started now. |
| N-12 | Required / explicit | Use logical Git commits for project work, preserve existing work, and stop at the current documentation review boundary. |

## 5. Application mapping and ownership

| Application need | PULSE function | Why | Responsibility outside PULSE |
| --- | --- | --- | --- |
| Noisy level sensor | Stability qualification/debounce | Prevent short sampled noise from changing accepted level inputs. | SENTINEL/integration defines sensor meaning, polarity, and coherent delivery. |
| Suspected dry-run | Configurable one-shot window | Indicate that the allotted response time has elapsed. | GUARDIAN defines the start event and expected validated response, decides fault status, and drives the pump. |
| Pump protection timing | Measured delay/window | Make a decision depend on a documented interval rather than incidental FSM execution time. | GUARDIAN decides stop/retry/latching and response-versus-timeout priority. |
| Periodic sampling/status, if needed | Optional clock-enable event | Supply a repeatable update cadence to an identified consumer. | Integration/VOICE must identify that consumer and its period. |

The later digital application must demonstrate normal LOW → MID → HIGH filling, noise rejection, absent response during pumping, defined recovery, and reset at different stages (§21). These are required scenarios; exact level encodings, pump activation delays, recovery rules, and any fault latch are **not** supplied requirements. They must be agreed or explicitly assumed before the application model/FSM is written.

## 6. Engineering assumption register

Every entry is a **working engineering assumption**, not a claim about physical hardware or another team's implementation. F-11 remains optional and is excluded from the baseline because no periodic consumer is confirmed. The digital application adds explicit scenario assumptions in [water-tank behavior](WATER_TANK_BEHAVIOR.md).

| ID | Proposal | Reason / alternative |
| --- | --- | --- |
| A-01 | One rising-edge system-clock domain; illustrative `CLOCK_FREQ_HZ = 50_000_000`; intervals measured in whole system-clock cycles. | The prompt offers 50 MHz as an example. It gives simple 20 ns arithmetic and avoids prescaler phase ambiguity. A slower tick or different clock can be agreed if range/resource needs justify it. |
| A-02 | Active-high synchronous `reset`; integration supplies a reset meeting `clk` timing. Outputs become known on a reset-sampling edge. | A simple digital contract. An external asynchronous reset would need separately agreed conditioning; no board/reset circuit is assumed. |
| A-03 | One runtime-configured external one-shot plus independent sensor qualification; `TIMER_WIDTH = 32`. | At the illustrative clock this permits about 85.9 s. Longer requirements need a wider timer or an agreed timebase. Sharing one interval's state with debounce would obstruct concurrent protection. |
| A-04 | Capture `cfg_timer_cycles` on an accepted start. For nonzero N, complete after N full subsequent clock intervals. Normalize zero to one cycle. Ignore starts while busy; use a one-cycle completion event. | Prevent underflow, define the minimum, and avoid a restart/queue/acknowledge protocol. Alternatives include rejecting zero or retaining completion until acknowledged. |
| A-05 | `enable = 0` aborts the timer and clears sensor output/validity on the next clock edge; re-enable starts fresh qualification. `timer_cancel` only aborts the timer. | Distinguishes whole-block disable from normal end-of-monitoring. Pause/resume is unnecessary for the initial application. An integration that does not need disable can tie enable high; removing the port is another review option. |
| A-06 | Initial `SENSOR_CHANNELS = 2` means two independent Boolean inputs, with no assigned bit meanings. PULSE provisionally owns two-stage synchronization per input. | Two predicates can be useful for lower/upper threshold integration, but the actual SENTINEL interface is unknown. A coherent encoded word needs a different, agreed transfer contract. |
| A-07 | Common elaboration-time `DEBOUNCE_CYCLES = 1_000_000` (20 ms at 50 MHz), applying to both directions and initial qualification. | A review fixture, chosen to reject shorter observed disturbances while adding 20 ms of response latency. No measured sensor bounce or response limit is available. Runtime or asymmetric debounce is deferred until justified. |
| A-08 | Sensor output reset value is all zero with validity cleared. A channel becomes valid only after a complete observed stability interval. | A reset code must not silently be interpreted as measured LOW/MID/HIGH. Validity then describes the last qualified reading, not current agreement with raw input. |
| A-09 | Illustrative protection-window setting: 5 s, or 250,000,000 cycles at 50 MHz. | A demonstration interval 250 times the illustrative debounce duration, within a 32-bit counter. It is not a calibrated dry-run limit or a verified fill time. Actual setting requires GUARDIAN/application input. |
| A-10 | Periodic output is optional and is a `clk`-domain enable/event, never an internal clock. A 100 Hz example may be used only if an update consumer is agreed. | No current requirement forces periodic sampling. Direct clock sampling already supports debounce. A square-wave oscillator is not proposed. |
| A-11 | Timer priority: reset, disable, cancel, active counting/expiry, idle start. Current input mismatch takes precedence over debounce expiry. | Removes simultaneous-event ambiguity. A start coincident with expiry is ignored; cancellation at expiry suppresses completion. |
| A-12 | Pump actions, level-response definitions, recovery, and simultaneous response/timeout priority remain integration decisions. | Assigning these inside PULSE would invent GUARDIAN policy. No automatic retry or fault latch is proposed here. |

## 7. Open questions and dependencies

These items are **BLOCKED / REQUIRES TEAM INPUT** for a finalized integration contract. They do not block reviewing this provisional PULSE contract.

| ID | Input needed | Owner / effect |
| --- | --- | --- |
| Q-01 | Actual clock frequency, tolerance, reset polarity/style, and reset ownership? | Integration/clock owner (ANCHOR only if assigned). Confirms A-01/A-02 and all time conversions. |
| Q-02 | Number of sensor signals, threshold meanings, polarity, clock domain, update rate, and encoding? Who owns synchronization? | SENTINEL + integration. Confirms or replaces A-06; must resolve any multi-bit coherence issue. |
| Q-03 | Observed noise/bounce duration and maximum acceptable sensor response latency? Same debounce for rising/falling and all channels? | Sensor/application team. Confirms or replaces A-07. |
| Q-04 | What event starts monitoring: pump request or actual enabled state? What validated response ends it? Is one window sufficient? | GUARDIAN. Determines start/cancel use and whether extra timing instances are needed. |
| Q-05 | Required minimum/maximum protection duration and tolerable timing error, including qualification/decision latency? | GUARDIAN + application team. Confirms range/width and replaces the 5 s fixture. |
| Q-06 | Pump/reset behavior, fault recovery, and priority if a validated response and timeout are observed together? | GUARDIAN + integration. Required before implementing application behavior. |
| Q-07 | Can consumers capture one-cycle `timer_done` synchronously, and accept ignore-while-busy/cancel/disable semantics? | GUARDIAN + integration. Confirms the handshake and event persistence requirements. |
| Q-08 | Does VOICE or another block require periodic events, at what cadence and in which clock domain? | VOICE + integration. Decides whether F-11 becomes part of the design. |

## 8. Review and later verification

The initial review checked consistency, provenance, arithmetic, and interface completeness only. Architecture and state-machine design now define the implementation. Later reports distinguish actual HDL/test execution from planned checks.

Verification must cover reset during counting; start while busy and on expiry; zero/minimum/maximum intervals; configuration changes mid-count; cancellation/disable at expiry; repeated starts; sensor startup validity; noise and expiration-boundary changes; simultaneous timer/debounce operation; and the five application scenarios above. Periodic checks apply only if that extension is adopted. Concrete test IDs and evidence belong to the verification plan and traceability matrix.

The [project inventory](project_inventory.md) preserves the original reconnaissance snapshot. The [architecture](PULSE_ARCHITECTURE.md) and [state-machine specification](PULSE_STATE_MACHINES.md) carry the subsequent design decisions. External agreements Q-01 through Q-08 remain open without preventing a clearly provisional digital demonstration.
