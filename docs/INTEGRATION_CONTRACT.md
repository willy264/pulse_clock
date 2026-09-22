# PULSE integration contract

**PROVISIONAL — pending agreement with integration team.** This document records a working PULSE boundary and a simulation adapter, not a finalized interface from SENTINEL, GUARDIAN, VOICE, or ANCHOR.

Updated 2026-09-22 for [OSC-CONTRACT-1](OSCILLATOR_CONTRACT.md), the working periodic-tick decision for the user's oscillator-completion request. External assignment interpretation and consumers remain provisional.

## 1. Common contract

One rising-edge `clk` domain; active-high synchronous reset. Sample reset before relying on outputs. Sampled `enable = 0` aborts the timer, clears sensor acquisition/validity, and clears periodic phase/output. No derived clock is generated. All inputs other than sensor bits must be synchronous and known when relevant to the sampled operation; configuration is required to be known at capture. Runtime counts are unsigned system-clock cycles.

The complete per-port direction, width, active level, reset obligation, timing, producer, and consumer are defined in [PULSE_INTERFACE.md](PULSE_INTERFACE.md). Those tables are authoritative. W = TIMER_WIDTH defaults to 32; R = PERIOD_WIDTH independently defaults to 32; S defaults to 2; D defaults to 1,000,000, all with the bounds in the timing/architecture specifications. `PERIOD_WIDTH` is appended after the existing three top-level parameters.

## 2. Connections and handshakes

| Connection / signals | Direction and width | Validity and handshake | Reset behavior / assumption |
| --- | --- | --- | --- |
| System → PULSE: `clk`, `reset`, `enable` | Input, one bit each | All functional logic advances on rising clk; enable is abort/reinitialize, not pause. | Reset spans a rising edge. Clock/reset producer remains integration-owned; ANCHOR involvement is unconfirmed. |
| SENTINEL/adapter → PULSE: `sensor_in` | Input, S independent bits | May be asynchronous under the provisional two-stage ownership contract; not an encoded coherent word. No request/acknowledge. | No required physical reset value; PULSE ignores reset padding until fresh acquisition. |
| PULSE → GUARDIAN: `sensor_debounced`, `sensor_valid` | Outputs, S bits each | Interpret each value only when its valid bit is high. Stable reading remains held through candidate changes/noise; validity is historical qualification, not raw agreement. | Value zero and validity zero after reset/disable. Initial acceptance at a(2+D) for an input stable before first enabled capture a0. |
| GUARDIAN → PULSE: `timer_start`, `timer_cancel` | Inputs, one bit each | Start is a one-cycle strobe accepted only if old busy is low, enabled, and not cancelled. Cancel may be held; cancellation wins expiry. No queue/acknowledgement. | Ignored under reset/disable; cancel does not clear sensor qualification. |
| GUARDIAN/configuration → PULSE: `cfg_timer_cycles` | Input, W unsigned bits | Valid on accepted start; capture once. Zero normalizes to one. Out-of-range values must not be truncated by caller. | External value is not reset by PULSE; ignored during reset. |
| PULSE → GUARDIAN: `timer_busy`, `timer_done` | Outputs, one bit each | Busy spans active count; done is one clock interval at expiry with busy low. Consumer samples synchronously. Start on expiry is ignored; next edge may start again. | Both zero after reset/disable/cancel. No sticky event or interrupt protocol. |
| Synchronous periodic caller → PULSE: `periodic_enable` | Input, one bit | Local active-high operation request. First jointly enabled edge captures period. Sampled low clears only periodic state; no pause/resume. | Reset/global disable/local disable clears phase/output and outranks expiry. Timer/debounce continue through local periodic disable. |
| Synchronous periodic configuration → PULSE: `cfg_period_cycles` | Input, R unsigned bits | Known/in-range on capture; zero maps to one. Retained across all reloads; changes apply only after clear and restart. | External bus is not reset by PULSE; ignored while reset/disabled. |
| PULSE → synchronous event consumer: `periodic_tick` | Output, one bit | Capture at p0; first registered event after pP, then p2P/p3P. P > 1 gives one-cycle high; P = 1 gives consecutive high event cycles. A clocked consumer first acts at p(P+1). | Zero after each sampled clear. A later clear cannot undo the preceding high interval. Unit-bench event counting demonstrates use; no external consumer is assigned. |
| PULSE → VOICE/status adapter | No finalized direct connection | A synchronous adapter may retain/display qualified values, validity, and timing status. A slower/asynchronous consumer must agree event retention/coherent transport. | Adapter reset behavior and transport remain Q-08; raw one-cycle done is not promised to be directly visible. |

Periodic ports are part of the working `pulse_top` interface under OSC-CONTRACT-1. All instantiations must explicitly connect them, preferably by name. An unused extension requires `periodic_enable = 0`, a known zero configuration of the declared period width, and an unused tick connection; leaving its enable floating is invalid. Timer starts/cancels and sensor chatter cannot change periodic phase. Tick is a synchronous enable and must not be used as a generated internal clock. Cross-domain event transfer or a slower VOICE consumer requires a separately agreed adapter.

## 3. Demonstration adapter

The local `water_tank_controller` instantiates PULSE and maps `sensor_in[1:0]` to `{full, above_low}`. Codes 00/01/11 represent LOW/MID/FULL; 10 is contradictory. It uses runtime `cfg_protection_cycles`, drives start on the same edge that enables the pump, and cancels on qualified initial response. Pump/fault/manual-clear behavior is fully specified in [water-tank behavior](WATER_TANK_BEHAVIOR.md).

The adapter exposes qualified sensor status and timer busy/done for integration tests. `pump_enable`, `dry_run_detected`, `protection_active`, and `fault_clear` belong to the controller interface, not to `pulse_top`. In the demonstration, the fault/protection indicators are aliases of its latched PROTECTED state. None of these names are asserted to match another team's delivery.

The existing application does not need recurring events. It explicitly ties `periodic_enable` low, drives zero `cfg_period_cycles`, and leaves `periodic_tick` unused. It adds no periodic sampling, pump, recovery, or protection behavior. The standalone periodic bench demonstrates a synchronous event counter, while top-level integration tests exercise concurrent periodic/timer/sensor operation with periodic enabled.

Production compile/synthesis/editor source lists include `src/pulse_periodic.v` alongside timer, debounce, PULSE top, and application controller: five production files in total. Synthesis of the reusable PULSE top must retain the observable periodic function; synthesis of the application may optimize away its disabled instance. Resource/evidence reports must distinguish those tops.

## 4. Agreements still needed

Q-01…Q-08 in [requirements](PULSE_REQUIREMENTS.md) remain **BLOCKED / REQUIRES TEAM INPUT** for a finalized team contract. Resolve clock/reset/tolerance; sensor count, meaning, domain and coherent transfer; actual bounce/latency limits; the protection trigger, response, interval range and overlapping-window needs; reset/recovery and same-edge policy; event capture; and any VOICE periodic consumer.

The provisional digital demonstration and OSC-CONTRACT-1 implementation can run without those external agreements. The periodic feature is included in the working design; agreement on an actual VOICE consumer or a supervisor-requested square-wave interpretation remains separate. Moving to another sensor representation, clock domain, waveform contract, or fault policy requires an adapter/specification update and relevant tests; successful local simulation is not external interface approval.
