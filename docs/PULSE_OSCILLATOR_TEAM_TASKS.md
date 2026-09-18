# PULSE oscillator completion: parallel assignments for five people

Prepared: 2026-09-18. Revised to remove avoidable waiting between teammates.

Status: **Planning only. Pulse versus square-wave output remains undecided; no new implementation or verification is claimed.**

Implementation language: Verilog HDL (Verilog-2001).

The work is divided into individually deliverable packages and a final shared integration checkpoint. A member's individual handoff must not require another member's unfinished package. Actual verification of the finished oscillator and its integration necessarily use the real implementation; these are separate team completion gates, not evidence that one member must wait idle throughout their assignment.

The existing verified timer, debounce, and PULSE top are available to everyone now. Preserve their behavior and credit their existing implementation and verification. The lead reviews and coordinates; owners fix problems in their own contributions.

## One decision before assigning implementation

Choose the output type and distribute the same written interface/timing contract to everyone before starting the implementation deadline. This is a short shared kickoff decision, not a specification task assigned to Member 1 that blocks the other members.

The current [interface proposal](PULSE_INTERFACE.md) and [timing proposal](PULSE_TIMING_SPEC.md) already define a candidate periodic tick. A square wave needs different timing and duty-cycle semantics. The proposal is a starting option, not evidence of supervisor approval or a final choice.

| Contract item | Existing periodic-tick proposal | Square-wave alternative to settle if selected |
| --- | --- | --- |
| Output | `periodic_tick`: registered event/clock enable | Registered HIGH/LOW output; agree its port name |
| Configuration meaning | P full input-clock cycles between events | Prefer an explicit H input-clock cycles per half-period; agree units |
| Frequency | Event rate = input clock frequency / P | Output frequency = input clock frequency / (2 x H) |
| Startup | Capture at p0; first tick after pP; then p2P, p3P | Agree initial level and first toggle edge |
| Reset/enable | Active-high synchronous reset; global/local disable clears output and phase | Agree reset level and disable/restart behavior |
| Configuration update | Capture at start; changes apply after disable/re-enable | Agree capture/update boundary |
| Minimum setting | Zero maps to P = 1; P = 1 means HIGH every event cycle, without LOW gaps | Agree zero handling; H = 1 toggles every clock |
| Width/range | Agree positive counter width; current PULSE timer width defaults to 32 | Agree positive counter width and supported range |
| Module/files | Candidate `pulse_periodic`, matching `.v` module and bench names | Candidate `pulse_oscillator`, matching `.v` module and bench names |

At kickoff, record the selected column, all final port names/directions/widths, enable/reset priority at expiry, startup edge, configuration capture, minimum behavior, clock assumption, and intended use. For example, the existing illustrative input is 50 MHz; it is not a confirmed physical clock specification.

Use the system clock for internal sequential logic. A periodic output is data or a clock enable, not a new internal clock. Specify the one-edge observation delay when another clocked process consumes a newly registered tick. A square-wave contract using an odd full-period count needs explicit HIGH/LOW rounding rules if exact 50% duty cannot be represented.

Issue the agreed packet as a named specification revision, for example `OSC-CONTRACT-1`, on every task. Proposed amendments are reviewed together; no member silently changes the shared interface. If the assignment meaning is still unclear, resolve it with the supervisor before describing either choice as the required oscillator function.

Until this kickoff decision is made, everyone can inspect the baseline, set up tools, and prepare contract-independent material. Do not claim output-specific RTL is ready to assign while its requirement remains undecided.

## Assignment overview

The only shared starting inputs are the repository baseline, installed tools, and the kickoff contract. None of the individual handoffs below requires a newly completed file from another teammate.

| ID | Owner | Work package | Independent handoff | Later shared checkpoint |
| --- | --- | --- | --- | --- |
| OSC-01 | Member 1 | Requirements audit, timing calculations, and explanation | Reviewed contract analysis, worked edge/frequency tables, demo instructions | Replace planned examples with actual results and finalize traceability/report |
| OSC-02 | Member 2 | Standalone oscillator RTL and developer checks | New Verilog module, small smoke bench, own compile/run results, architecture notes | Resolve defects exposed by independent tests and synthesis |
| OSC-03 | Member 3 | Independent tests and checker validation | New unit testbench/checker, case matrix, checker self-test results | Run against Member 2's real module and export measured waveforms |
| OSC-04 | Member 4 | Baseline reproducibility, integration preparation, and tools | Actual baseline reproduction, wiring/source-list change plan, prepared integration patch | Integrate real module/tests; run concurrency, full regression, and synthesis |
| OSC-05 | You, team lead | Scope, coordination, and review | Published contract, assigned tasks/deadlines, review checklist and progress board | Review integrated evidence and approve release/demo |

Individual handoff and whole-project completion are different statuses. Completing a testbench before the DUT arrives does not mean the oscillator has passed; reproducing the existing synthesis does not prove the new feature synthesizes.

## OSC-01 - Member 1: contract audit and presentation package

**Starts with:** The common repository and kickoff contract, not another member's code or results.

- [ ] Check the selected contract against the original assignment and current PULSE requirements. Record unresolved external questions separately.
- [ ] Calculate frequencies/periods for the agreed examples, including small boundary settings.
- [ ] Write expected edge tables for startup, at least three repetitions, reset/disable, and configuration changes.
- [ ] Explain how the feature complements the existing timer and how its output is used. Do not invent an application consumer.
- [ ] Write `docs/OSCILLATOR_DEMO.md` with the procedure and the specific signals/measurements the team will show.
- [ ] Prepare requirements/interface/timing/traceability updates from the shared contract. Mark expected results as expected, and leave measured results pending.

**Individual done when:** The calculations and edge tables are internally consistent, match the issued contract, and the explanation/demo procedure is ready for review. No new RTL, simulator transcript, or teammate-authored document is needed to submit this package.

**Primary ownership:** Requirements/interface/timing documentation, relevant integration-contract text, traceability/final-report updates, and the demo guide. Member 1 audits and explains the kickoff contract; they are not its prerequisite author for everybody else.

**At the shared checkpoint:** Add the actual results from OSC-03/04, keep external agreements provisional unless obtained, and demonstrate the feature using real waveforms.

## OSC-02 - Member 2: standalone RTL with its own smoke test

**Starts with:** The frozen module interface/timing contract and existing tool instructions.

- [ ] Implement the selected new `.v` module with independent counter/reload state and the required pulse/toggle behavior.
- [ ] Implement capture, repeated operation, reset/enable priority, minimum values, and restart phase exactly as specified.
- [ ] Preserve the captured configuration across reloads where required; do not accidentally resample live configuration every period.
- [ ] Use Verilog-2001, explicit widths, and one sequential owner per register. Leave existing timer/debounce RTL unchanged unless a separately reviewed issue requires it.
- [ ] Write a small developer smoke bench for startup, repeated output, reset, and enable. This belongs to Member 2; waiting for Member 3's independent suite is unnecessary.
- [ ] Compile and run the module/smoke bench in a fresh local work library with ModelSim `-vlog01compat`. Record exact commands, revision, and actual outcomes.
- [ ] Update architecture/state notes and explain each register and boundary decision.

**Individual done when:** The standalone module compiles and passes its own documented smoke checks, and its source/notes can be handed over. Independent verification and integration are explicitly still pending.

**Primary ownership:** New `src` module, a separate developer smoke fixture (distinct filename/module from OSC-03's bench), and architecture/state notes. Temporary smoke artifacts must be outside production source lists; commit any fixture needed to reproduce claimed evidence.

**At the shared checkpoint:** Fix module defects found by OSC-03 or OSC-04. Member 2 retains responsibility for those fixes rather than passing them to the lead.

## OSC-03 - Member 3: independent unit tests and checker self-test

**Starts with:** The same interface/timing contract, not Member 2's internal counter design.

- [ ] Create the independent unit bench using the agreed DUT module and port names.
- [ ] Calculate expected edges from the public contract rather than copying the DUT algorithm.
- [ ] Cover first output, at least three repeated periods, zero/minimum behavior, odd/even representative settings, and all settings at a practical reduced width.
- [ ] Check pulse width or HIGH/LOW durations, configuration changes during counting/across reloads, reset/global/local disable at expiry, and restart behavior.
- [ ] Add bounded large-count public-output checks for no premature event and correct abort. Claim exact internal capture/decrement only if suitable observability is agreed and tested at the shared checkpoint; do not claim unrun full maximum durations.
- [ ] Include explicit failure reporting, success status, and bounded timeout behavior compatible with the existing runner.
- [ ] Validate the checker before the DUT is available by feeding a small set of predetermined correct and deliberately incorrect transition schedules: early/late output, wrong width, or output after reset. Use a testbench-only checker self-test entry point that does not instantiate the missing DUT.
- [ ] Record which good schedules were accepted and which bad schedules were rejected. Prepare the waveform-export procedure and case-to-requirement matrix.

**Individual done when:** The independent bench/case matrix is ready and the checker self-test demonstrably accepts/rejects the intended schedules. This status is **checker validated; production DUT execution pending**, never oscillator PASS.

**Primary ownership:** New independent `tb` bench, a minimal testbench-only checker fixture, verification plan, waveform observations, and later evidence exports. Keep a separate compile/run entry point for the checker self-test. Predetermined schedules need only exercise the checker; do not write a second complete oscillator to fill time.

**At the shared checkpoint:** Connect the actual module, run every required case, verify that deliberate failures are rejected by the real runner, and save measured oscillator waveforms. Real-module results supersede any fixture-only readiness evidence.

## OSC-04 - Member 4: tool validation and integration preparation

**Starts with:** The existing working repository and the kickoff port/file contract. The current baseline is already available for actual tool runs.

- [ ] Reproduce all existing testbenches and both Quartus synthesis checks from a clean checkout on the available validation machine.
- [ ] Record actual tool versions, source revision, commands, run paths, errors/warnings, and resource reports. Resolve setup or portability issues in this baseline.
- [ ] Confirm portable TerosHDL paths and source classification and verify the documented setup procedure.
- [ ] Prepare the precise `pulse_top` port/instance wiring and identify every existing instantiation that needs updating. Explicitly disable an unused extension in the current application; new water-tank behavior is outside this assignment.
- [ ] Prepare source-list/runner changes for the agreed filenames in ModelSim, Quartus, and TerosHDL. Keep proposed changes on the integration branch; do not merge compile lists referring to absent files into a working baseline.
- [ ] Prepare concurrency scenarios: periodic output while timer starts/cancels and sensors change/chatter; periodic local enable changes while timer/debounce continue.
- [ ] Prepare the clean-build, synthesis, and clean-clone checklist and report format for the integrated design.

**Individual done when:** Actual baseline reproduction is documented and the integration patch/scenarios/configuration changes are ready for review against the agreed ports. This does not require the new module or Member 3's tests to be finished. Mark unavailable integrated runs as pending.

**Primary ownership:** PULSE top and affected instantiation connections, top-level integration tests, ModelSim/Quartus/TerosHDL configuration, simulation guide, and synthesis report. Preserve the baseline on a clean checkout while preparing dependent edits on the integration branch. A proposed patch is not a completed integration.

**At the shared checkpoint:** Substitute the real implementation and independent tests, then run concurrency checks, the full regression, and synthesis for both tops. Ensure the new function remains observable/synthesized at `pulse_top` even if the application disables it. Reproduce the final result from a fresh checkout and account for warnings. Member 4 fixes integration/configuration defects; Member 2 fixes module defects.

## OSC-05 - You: kickoff, accountability, and review

**Starts with:** The existing project and these assignments.

- [ ] Settle the output choice, publish the common contract revision, and record any still-provisional external assumptions.
- [ ] Assign names and deadlines separately for individual handoffs and the final integration checkpoint.
- [ ] Give each member ownership of their branch and files; establish reviewers without making draft submission depend on reviewer availability.
- [ ] Use a task board with: Not started, In progress, Individual handoff ready, Under review, Integrated, and Verified.
- [ ] Review evidence and return fixes to the responsible owner; do not become the automatic implementer for late work.
- [ ] Prepare the final release checklist and demonstration responsibilities before integration arrives.

**Individual done when:** Everyone has an agreed starting contract, a concrete deliverable, a deadline, and clear file ownership; review/release criteria are published. Other members' finished code is not required for this coordination package.

**At the shared checkpoint:** Review PRs and final evidence, require relevant reruns after executable changes, and approve completion only when the real module, independent tests, integration, synthesis, and documentation agree. Each person demonstrates their own work.

## Progress and waiting policy

Use one task/issue per owner. Suggested branches: `oscillator/documentation`, `oscillator/rtl`, `oscillator/unit-tests`, and `oscillator/integration`. Preserve individual commits and authorship.

Each progress update should contain:

1. A link to the actual artifact or commit produced.
2. Checks run, their outcome, and whether they used baseline RTL, a checker fixture, or the new real module.
3. The next independently executable action.
4. Any specific blocker, its owner, and which remaining actions are unaffected.

A real missing requirement or unavailable tool must be reported honestly. "Waiting for another member" alone is not a complete update while that person's independent checklist still contains executable work. Once the independent package is finished, a genuine integration wait is legitimate: submit it for review, help review other packages, and label final results pending. Do not manufacture busywork or require fabricated test results to hide a dependency.

Example: Member 3 can finish the case matrix and prove the checker rejects an early pulse before Member 2 finishes RTL. They cannot claim the real oscillator passes until they test it. Member 4 can complete actual baseline reproduction before new source files arrive; only the new integrated result waits.

## Shared integration and release gate

This is the only phase that intentionally combines everyone's deliverables. It is coordinated by the lead, executed by the appropriate owners, and does not transfer all remaining coding to the lead.

- [ ] Member 2's module and Member 3's tests use the same accepted contract revision.
- [ ] Real-module independent tests pass, with correct startup, periods, widths/duty, configuration, reset, and restart behavior.
- [ ] Member 4's concurrency tests prove independent timer/debounce/periodic operation.
- [ ] All existing regression intent is preserved and all required old/new benches pass in fresh libraries.
- [ ] No checker fixture or placeholder is used as the delivered oscillator or as its synthesis evidence.
- [ ] Quartus Analysis & Synthesis passes for both production tops; warnings and resource changes are reviewed.
- [ ] Measured waveforms agree with self-checks and clearly identify the tested source revision.
- [ ] A fresh checkout reproduces the integrated result without copied build artifacts.
- [ ] Member 1 updates evidence/traceability/report/demo with actual results, and each owner reviews their portion.
- [ ] The lead approves the complete release and all members can explain their contribution.

Keep `main` runnable. Combine RTL, independent tests, and integration on a review branch before merging changes that rely on each other. Readiness of an individual's branch does not require prematurely merging an incomplete feature into `main`.

The original timer's additional cancellation boundary and optional five-second run remain separate backlog items. Physical hardware, new water-tank behavior, and extra features introduced only to occupy team members are outside this work package.
