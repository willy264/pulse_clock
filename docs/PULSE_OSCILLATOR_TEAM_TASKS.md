# PULSE oscillator completion: assignments for five team members

Prepared: 2026-09-18. Status: **Task plan; oscillator implementation and new verification are not yet complete.**

Implementation language: Verilog HDL (Verilog-2001).

This plan divides the oscillator extension between four teammates and the team lead. Replace Member 1–4 with names when assigning work. The existing timer, debounce, and PULSE integration form the verified starting point; preserve their behavior and credit the work already completed.

The RTL for a periodic generator is relatively small. A complete contribution also needs an agreed specification, independent tests, integration, measured evidence, synthesis review, and a demonstration. Those responsibilities support five meaningful assignments without inventing extra features or splitting one counter between five programmers. Workloads will not be identical; review and verification are technical work too.

## Assignment overview

| ID | Owner | Assignment | Concrete handoff | Reviewer |
| --- | --- | --- | --- | --- |
| OSC-01 | Member 1 | Define oscillator behavior and prepare the explanation/demo | Agreed timing/interface contract, requirements mapping, demo instructions | You and Member 3 |
| OSC-02 | Member 2 | Implement the standalone oscillator/periodic generator | Verilog module, architecture notes, compile evidence | Member 3; Member 4 checks ports |
| OSC-03 | Member 3 | Independently verify the new module | Self-checking testbench, case matrix, measured waveform evidence | Member 1 checks against specification; you review conclusions |
| OSC-04 | Member 4 | Integrate with PULSE and validate the tool flow | Updated top/connections/configuration, concurrency tests, clean simulation and synthesis results | Member 2 reviews wiring; you review release evidence |
| OSC-05 | You, team lead | Coordinate scope, review contributions, and prepare the release | Accepted contract, reviewed PRs, completion checklist and final demonstration approval | All members review the completed checklist |

Each owner investigates and fixes problems in their own deliverable. The lead coordinates disagreements and reviews evidence; unfinished implementation does not automatically transfer to the lead.

## Start together: agree what “oscillator” means

The existing [interface proposal](PULSE_INTERFACE.md) and [timing proposal](PULSE_TIMING_SPEC.md) describe periodic clock-enable pulses. A square wave requires a different output contract. Neither implementation is selected by this task plan.

| Choice | Required behavior | Frequency relationship |
| --- | --- | --- |
| Periodic tick | One event every P input-clock cycles; normally one cycle HIGH | Event rate = input clock frequency / P |
| Square wave | Toggle output every H input-clock cycles, producing H HIGH and H LOW cycles | Output frequency = input clock frequency / (2 × H) |

Both use the external system clock. This work is a synchronous digital generator; a physical free-running oscillator is outside the software/RTL scope. Keep PULSE's internal sequential logic on the system clock. A periodic output is consumed as an enable or observed as data, not silently used as a new internal clock.

Before implementation, Member 1 records agreement on:

- Pulse or square wave, its assignment requirement, and its intended use/consumer. If there is no application consumer, state that honestly and confirm the standalone educational requirement with the supervisor.
- Input-clock assumption, requested output range, configuration units, width, and valid limits. Distinguish full period P from half-period H.
- Reset polarity/style and reset output level; retain compatibility with PULSE's active-high synchronous reset.
- Global and local enable behavior, first-output edge, and restart phase after disable.
- Zero/minimum configuration behavior and priority when reset/disable coincides with expiry.
- When configuration is captured and when a new value may take effect.
- Pulse width or square-wave duty cycle, including any limits or rounding rules.
- Module name and every port name, width, direction, and timing obligation.

If the existing tick proposal is adopted, capture P = max(1, configuration) at start, emit at P, 2P, 3P subsequent cycles, and hold the captured period until disable/re-enable. P = 1 produces a HIGH level on every active event cycle without a LOW gap. A separate clocked consumer observes a newly registered output on the following edge; document that latency in any usage example.

For a square wave, explicitly define H and the initial phase. H = 1 toggles every input cycle. A configurable odd full-period count cannot have equal integer HIGH and LOW durations, so do not promise exact 50% duty for such a contract without defining how it is handled.

The team can read code, reproduce the baseline, and prepare test cases immediately. RTL implementation and expected-output calculations depend on the agreed contract. Record external agreement only when it has actually been obtained.

## OSC-01 — Member 1: specification, documentation, and demonstration

**Objective:** Make the required behavior precise enough that another person can implement and test it independently.

Tasks:

- [ ] Read the current requirements, interface, timing, architecture, and integration contract.
- [ ] Resolve the output choice and record all decisions in the checklist above, including their source.
- [ ] Update F-11 and the periodic portions of the interface/timing documents to reflect the adopted scope. Keep unrelated team interfaces provisional until actually agreed.
- [ ] Supply worked timing examples for a small configuration and a useful illustrative frequency.
- [ ] Explain startup, normal operation, configuration changes, and reset/disable with edge tables.
- [ ] Update traceability and final-report descriptions using results supplied by Members 3 and 4; identify planned versus executed checks.
- [ ] Write `docs/OSCILLATOR_DEMO.md` with the commands and waveforms needed to explain and demonstrate the feature.

**Primary files:** `docs/PULSE_REQUIREMENTS.md`, `docs/PULSE_INTERFACE.md`, `docs/PULSE_TIMING_SPEC.md`, relevant portions of `docs/INTEGRATION_CONTRACT.md`, `docs/TRACEABILITY_MATRIX.md`, `docs/FINAL_REPORT.md`, and the new demo guide.

**Done when:** The lead and verifier accept an unambiguous contract; another teammate can follow the demo instructions; every reported result names actual evidence. Member 1 can explain frequency calculation, startup, and reset behavior without reading a script.

**Dependency:** Starts immediately. Final result/documentation updates follow OSC-03 and OSC-04.

## OSC-02 — Member 2: standalone Verilog implementation

**Objective:** Implement the agreed recurring output with clear counter ownership and predictable timing.

Tasks:

- [ ] Implement one new module, provisionally `src/pulse_periodic.v` for ticks or `src/pulse_oscillator.v` for a square wave; freeze the name with OSC-01.
- [ ] Use a counter and reload/toggle logic appropriate to the selected contract.
- [ ] Preserve captured configuration across reloads when the contract requires it; do not accidentally resample the live configuration at every period.
- [ ] Implement documented reset, enable, restart, minimum-value, and priority rules.
- [ ] Use explicit widths, Verilog-2001 syntax, and one sequential owner per register. Keep diagnostic behavior compatible with the existing tools.
- [ ] Compile the module with ModelSim's `-vlog01compat` setting and resolve syntax/width issues.
- [ ] Update architecture/state descriptions and give Member 3 the module for independent verification.
- [ ] Investigate and fix RTL defects reported by verification or synthesis; explain each behavioral fix.

**Primary files:** The new `src` module, `docs/PULSE_ARCHITECTURE.md`, and applicable sections of `docs/PULSE_STATE_MACHINES.md`.

**Done when:** The code matches the accepted contract, independent unit tests pass, and the module passes the integrated synthesis review. Member 2 can explain each register, reload condition, and boundary case.

**Dependency:** Contract and ports from OSC-01. Work proceeds alongside OSC-03 after agreement.

## OSC-03 — Member 3: independent verification and waveforms

**Objective:** Demonstrate correct behavior from the public contract, including faults that a basic “output toggles” test would miss.

Tasks:

- [ ] Build a dedicated Verilog testbench for the new module, named consistently with OSC-02.
- [ ] Calculate expected event/transition edges from the specification, independently of the DUT's counter implementation.
- [ ] Check the first output and at least three consecutive periods for representative settings.
- [ ] Cover zero according to the contract, minimum values, odd/even settings, and all settings at a practical reduced width.
- [ ] Check pulse width or separate HIGH/LOW durations. Include P = 1 continuous enable for ticks, or H = 1 alternating output for a square wave.
- [ ] Change configuration during counting and across reloads; prove changes apply only at the agreed boundary.
- [ ] Exercise reset, global disable, and local disable during operation and exactly at expiry; verify complete restart timing.
- [ ] Check large configuration capture, decrement, and abort efficiently. Label any full maximum-duration test that was not run.
- [ ] Use explicit pass/fail checks, `test_passed`, and a watchdog consistent with existing Verilog benches. An intentionally failing check must be rejected by the runner.
- [ ] Save representative measured waveform exports and explain the exact edges that establish period, startup, and reset/disable behavior.
- [ ] Update the verification plan and waveform observations; report any coverage limit honestly.

**Primary files:** The new `tb` bench, `docs/PULSE_VERIFICATION_PLAN.md`, `docs/WAVEFORM_OBSERVATIONS.md`, and small evidence artifacts under `docs/waveforms/`. Generated simulation libraries remain under ignored `build/` directories.

**Done when:** The bench detects incorrect timing rather than merely printing PASS, all required cases pass on the final RTL, and waveform measurements agree with the checks. Member 3 can explain what each test establishes and what remains untested.

**Dependency:** Agreed contract from OSC-01. Cases and expected edges can be designed while OSC-02 is being implemented; execution requires the module.

## OSC-04 — Member 4: PULSE integration, build configuration, and synthesis

**Objective:** Make the new function work with the existing PULSE core without disturbing timer or debounce behavior.

Tasks:

- [ ] Add the module and agreed ports to `src/pulse_top.v`.
- [ ] Update existing PULSE instantiations for the new interface. In the current water-tank adapter, explicitly disable the extension if it is unused; no new water-tank behavior is part of this assignment.
- [ ] Extend `tb/pulse_top_tb.v` to run periodic output alongside timer start/cancel and independently changing/noisy sensor channels.
- [ ] Check that periodic deadlines remain fixed during timer/sensor activity, and that local periodic enable changes leave the other functions operating correctly.
- [ ] Coordinate expected integration deadlines with Member 3, including registered-output observation latency.
- [ ] Update ModelSim compile/run lists, the portable TerosHDL project, and Quartus source assignments for all new files and benches.
- [ ] Run the new unit bench and every existing bench from fresh simulation libraries; preserve existing verification intent.
- [ ] Run Quartus Analysis & Synthesis for both existing tops and review warnings. If the application ties the feature off and synthesis removes it there, ensure `pulse_top` exposes and synthesizes it.
- [ ] Check the portable project and scripts from a clean clone on the validation machine. Ask another teammate to reproduce the setup on their machine where the tools are available.
- [ ] Record commit, tool versions, commands, run directories, results, resources, and remaining warnings. Update the simulation guide and synthesis report.

**Primary files:** `src/pulse_top.v`, necessary connection updates in `src/application/water_tank_controller.v` and its bench, `tb/pulse_top_tb.v`, `sim/`, `synth/`, `pulse.teroshdl.yml`, `docs/SIMULATION_GUIDE.md`, and `docs/SYNTHESIS_CHECK.md`.

**Done when:** All existing and new required tests pass in a clean build, concurrency checks pass, both synthesis tops pass with reviewed warnings, and the portable project lists resolve. Do not infer a new PASS from old transcripts.

**Dependency:** Integration preparation starts after OSC-01; final execution needs OSC-02 and OSC-03. Member 4 owns integration/configuration fixes; Member 2 owns defects inside the new RTL module.

## OSC-05 — You: technical lead, review, and release

**Objective:** Keep the scope coherent and accept evidence-backed contributions without becoming the default implementer for all four assignments.

Tasks:

- [ ] Assign names, availability, and agreed deadlines to OSC-01–04. Confirm that each person can access the repository and existing instructions.
- [ ] Agree the output contract with Member 1 and the verifier before implementation begins.
- [ ] Maintain the task board and review dependency/blocker updates. Route technical defects to their owners.
- [ ] Review the four deliverables and require cross-review; do not accept screenshots or PASS messages without a reproducible source/command/result link.
- [ ] Coordinate PR merge order and keep `main` consistent. Require owners to resolve their own review comments and update branches.
- [ ] Verify Member 4's final evidence corresponds to the final integrated executable revision; require relevant reruns after subsequent code changes.
- [ ] Review the demo and let every teammate explain their own contribution, including limitations.
- [ ] Approve the completed checklist and release/report only when the evidence supports the claimed oscillator functionality.

**Primary ownership:** Task board, scope decisions, PR reviews, completion checklist, and release coordination. Specialist file edits remain with OSC-01–04.

**Done when:** Contributions are reviewed and integrated, completion criteria below are met, and the team can demonstrate the result without relying on you to explain every subsystem.

## Work order and Git handoffs

1. Everyone reproduces the documented baseline and reads their assigned source/docs. This is onboarding, not a request to rewrite verified work.
2. Member 1 drafts the contract; you and Member 3 review it. Settle the output choice before coding the feature.
3. Members 2 and 3 develop RTL and independent tests in parallel. Member 4 prepares the top-level wiring and tool updates from the agreed ports. Member 1 prepares the demo outline.
4. Member 3 tests the RTL; Members 2 and 4 fix module and integration defects in their respective areas.
5. Member 4 runs the complete clean regression/synthesis and records evidence. Member 1 updates traceability/report/demo using those results.
6. You review the final package; each member demonstrates their contribution.

Use one main task/issue per assignment, with the checklists above as subtasks. Suggested branch names are `oscillator/specification`, `oscillator/rtl`, `oscillator/unit-tests`, and `oscillator/integration`. Avoid simultaneous edits to another owner's files; agree any shared-file changes first.

Suggested PR order: specification; implementation with independently reviewed unit tests; integration/tooling with complete regression; final evidence/documentation. Cross-branch integration can be tested on the integration branch before merging so `main` does not temporarily contain a broken build. If RTL and unit tests are developed on separate branches, combine them into a reviewable passing change while preserving individual commits and authorship.

Every PR should name the task, behavior changed, source revision, verification commands/results, and unresolved limits. Reuse the existing scripts; add a new bench to their supported test list instead of relying on an undocumented personal flow. The lead approves merges, while owners prepare and correct their own contributions.

## Team completion checklist

- [ ] Pulse or square-wave requirement, intended use, and interface are explicitly agreed.
- [ ] The output period, startup, minimum settings, enable/reset, and reconfiguration behavior match the contract.
- [ ] New HDL and testbenches use Verilog-2001 and `.v` files.
- [ ] Independent unit tests and PULSE concurrency tests pass.
- [ ] Existing timer, debounce, top-level, and application regression intent is preserved and all required tests pass.
- [ ] Measured waveform evidence agrees with the self-checks and states what it demonstrates.
- [ ] Clean ModelSim compilation/regression and Quartus Analysis & Synthesis pass; warnings and resource changes are explained.
- [ ] A fresh checkout reproduces the recorded results with no copied build artifacts.
- [ ] Requirements, interface, timing, architecture, verification, traceability, and final report describe the delivered feature accurately.
- [ ] Each member has an identifiable contribution and can explain it during the demonstration.

Existing verification follow-ups, such as timer cancellation one cycle before expiry and a practical full five-second run, remain separate backlog items. Do not silently attach them to the oscillator assignment or claim that adding the oscillator closes them. Physical hardware and new water-tank behavior are also outside this work package.
