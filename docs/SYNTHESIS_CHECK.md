# Quartus analysis and synthesis check

Executed on 2026-09-22 with Quartus II 64-bit **13.0.1 Build 232 SP1 Web Edition** using `synth/run.ps1`. Both default-parameter tops completed Analysis & Synthesis with **0 errors and 1 warning each**, including a fresh checkout of executable revision `15857ae6b79d84b10c619ce947af10efca7a1de6`.

Implementation language: Verilog HDL (Verilog-2001).

## Scope

The generated projects target representative Cyclone IV E `EP4CE22F17C6` solely for RTL analysis. The five synthesizable sources are `pulse_timer.v`, `pulse_debounce.v`, `pulse_periodic.v`, `pulse_top.v`, and `application/water_tank_controller.v`. Testbenches/models and simulation diagnostic checks within synthesis translate-off regions are excluded. `pulse.sdc` records the illustrative 50 MHz clock. `synth/check.tcl` generates QPF/QSF projects with `VERILOG_FILE` and `VERILOG_INPUT_VERSION VERILOG_2001` assignments.

No fitter, pin assignment, programming image, device programming, post-fit timing analysis, CDC MTBF analysis, or netlist-equivalence run was performed. These results establish tool acceptance and synthesized resources; they do not establish physical timing closure.

## Observed reports

Workspace run: `build/quartus/run-20260922-102633-279`. Final clean-checkout run: `build/quartus/run-20260922-105734-620`, relative to the clone recorded in [completion evidence](OSCILLATOR_COMPLETION.md). Each top has `output_files/<top>.map.rpt`, `.map.summary`, generated QPF/QSF, and `quartus.log`. Both runs agree:

| Top | Estimated logic elements | Registers | Errors | Warnings |
| --- | --- | --- | --- | --- |
| `pulse_top` | 385 | 158 | 0 | 1 |
| `water_tank_controller` | 241 | 96 | 0 | 1 |

A fresh baseline run before this extension reported core 224 logic elements/92 registers and application 241/96. The core adds 161 logic elements and 66 registers for the separately controlled periodic function. The application holds `periodic_enable` LOW, allowing Quartus to remove the unused generator; its resources are unchanged.

These are pre-fit estimated logic elements, not final area. Informational implementation messages report **387/242 logic cells**, a distinct report field. No power/area target was supplied.

## Warning and information review

| Diagnostic | Meaning and disposition |
| --- | --- |
| Warning 20028: parallel compilation not licensed; disabled | Installed licence capability. Serial analysis completes successfully. This is the only warning in either top. |
| Info 17049, application only: two registers lost fanouts | The controller state registers `state~2` and `state~3` are removed during optimization, as in the baseline. This informational message is not a warning. No netlist-equivalence proof is claimed. |

No latch, multiple-driver, width-truncation, unsupported-construct, or combinational-loop warning was reported. Independent source review covered complete assignments, register ownership, count widths, and reset/disable priorities. The simulator's guards for invalid width and unknown controls are excluded from synthesis.

## Reproduction

Run `./synth/run.ps1` from PowerShell with Quartus discoverable from PATH, `QUARTUS_ROOTDIR`, or `-QuartusBin`. Each invocation creates fresh projects and preserves prior evidence. The [historical conversion report](VERILOG_CONVERSION.md) records the earlier language-migration results; [current completion evidence](OSCILLATOR_COMPLETION.md) records both baseline reproduction and the final periodic implementation. Generated reports remain the source of truth when repeating on another machine/version.
