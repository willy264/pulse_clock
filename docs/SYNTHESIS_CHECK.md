# Quartus analysis and synthesis check

Executed on 2026-09-10 with Quartus II 64-bit **13.0.1 Build 232 SP1 Web Edition** using `synth/run.ps1`. Both default-parameter tops completed Analysis & Synthesis with **0 errors and 1 warning each**.

## Scope

The generated local projects target representative Cyclone IV E `EP4CE22F17C6` solely to make RTL analysis concrete. This is not a selected university board or physical implementation. The four `src` files are synthesized; `tb` models and diagnostic assertions within synthesis translate-off regions are excluded. `pulse.sdc` records the illustrative 50 MHz clock.

No fitter, pin assignment, programming image, device programming, post-fit timing analysis, CDC MTBF analysis, or netlist equivalence run was performed. These results establish that the installed synthesis tool accepts the RTL; they do not establish 50 MHz timing closure or physical reliability.

## Observed reports

Initial repository run: `build/quartus/run-20260910-023045-118`. Each top has an `output_files/<top>.map.rpt`, `.map.summary`, generated QPF/QSF, and `quartus.log`.

| Top | Estimated logic elements from map report | Registers from map report | Errors | Warnings |
| --- | --- | --- | --- | --- |
| `pulse_top` | 224 | 92 | 0 | 1 |
| `water_tank_controller` | 241 | 96 | 0 | 1 |

These are pre-fit analysis/synthesis counts, not final fitted area. The informational implementation messages report 225/242 logic cells; that is a different report field and is not substituted for the estimated logic-element values above. There is no power/area target supplied by the project.

## Warning and information review

| Diagnostic | Meaning and disposition |
| --- | --- |
| Warning 20028: parallel compilation not licensed; disabled | Installed license/tool capability. The analysis continues serially and succeeds. Retained and documented; no tool installation or license change is required for the present check. |
| Info 17049, application only: two registers lost fanouts | Report identifies `state~2` and `state~3` removed during netlist optimization. Reviewed as synthesis optimization of controller state; it is not a warning or an observed functional failure. No netlist-equivalence proof is claimed. |

No latch, multiple-driver, width-truncation, or combinational-loop warning was reported in these runs. Static source review also checks complete combinational assignments, one sequential owner per register, explicit unsigned counters, synchronization ownership, and reset/disable priorities. Diagnostic checks for unknown reset/enable are synthesis-excluded and cannot affect area or function.

## Reproduction and limits

Run `./synth/run.ps1` from PowerShell with Quartus discoverable from PATH, QUARTUS_ROOTDIR, or `-QuartusBin`. A new project directory is created every time; existing reports are preserved. A separate clean-checkout execution is recorded in the [final report](FINAL_REPORT.md). Use the warnings in the generated reports as the source of truth on another machine/version.
