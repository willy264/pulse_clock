# Project inventory

Inspection date: 2026-09-10. Team: PULSE.

Scope: Phase 0 reconnaissance and the four-document review package requested by master prompt §37.

## 1. Workspace found at entry

Workspace: `C:\Users\HP\Documents\people\pulse_clock` on Windows, using PowerShell.

The directory contained **zero files and zero child directories**, including hidden entries. `Get-ChildItem -Force`, a recursive file enumeration, and `rg --files --hidden -g '!.git'` found no project content. `git status --short --branch` and `git rev-parse --show-toplevel` reported that this was not a Git repository. There was consequently no tracked work, branch, history, remote, naming convention, or existing HDL to inspect or preserve.

No `AGENTS.md` was found in the workspace or at any ancestor directory up to `C:\`. The empty workspace also contained no descendant instructions.

| Category | Existing project files at entry | Implication |
| --- | --- | --- |
| HDL (`.sv`, `.v`, `.vhd`) | None | No modules, ports, counter implementation, or reset convention to inherit. |
| Requirements/application specification | None | The supplied attachment is the sole project authority available. |
| SENTINEL/GUARDIAN/ANCHOR/VOICE interfaces | None | All proposed connections must be marked provisional. |
| TerosHDL / VS Code project settings | None | No project tool selection or file list exists. |
| ModelSim (`modelsim.ini`, `.mpf`, `.do`, libraries) | None | No project library mappings, compile order, simulation scripts, or wave setup. |
| Quartus (`.qpf`, `.qsf`, `.sdc`) | None | No target device, pin assignment, clock constraint, or synthesis project. |
| Tests, digital tank/sensor/pump models | None | No existing functional verification or simulation results. |
| Build/CI/dependency manifests | None | No automation or external project dependency is defined. |
| Git metadata | None | A local repository was initialized on `main` during this documentation pass to support logical commits; no remote was configured. |

This table records the state **before** the documentation was created. The completed review package consists of the four files in section 5, plus local Git metadata.

## 2. Requirements source

The latest user attachment is titled **MASTER PROJECT PROMPT — Water Tank Level & Dry-Run Protection Controller**:

- Local source: `C:\Users\HP\.codex\attachments\3a405d32-8fd0-4b72-a830-09a87a8ea0c6\pasted-text.txt`.
- SHA-256: `8304DD4F446B9D3EA61B365FF3BE465400B2811E38B75EE6B68A06CA00FAB9E5`.
- Read as UTF-8; no additional university project sheet or other-team contract was supplied.
- Sections 1–5 define the role and capabilities; section 37 limits the current work to reconnaissance and four initial documents, then a review stop. The broader implementation plan describes later phases.

The attachment path is provenance on this workstation, not a build dependency. The documents record the relevant requirements and assumptions in repository files. The prompt's 50 MHz, 20 ms, example module names, and example ports are examples, not fixed application requirements.

## 3. Installed tools and verification limits

The user-listed toolchain was checked using command discovery, scoped installation/configuration inspection, and version queries. No tools were installed or reconfigured.

| Tool | Observed version / discovery | Validation performed |
| --- | --- | --- |
| ModelSim-Altera | Altera Starter Edition **10.1d, 2012.11**; `vsim`, `vlog`, `vlib`, and `vmap` on PATH under `C:\altera\13.0sp1\modelsim_ase\win32aloem` | `vsim -version` and `vlog -version` succeeded. `vlib`/`vmap` resolve, but `-version` returned usage, so those utilities have not been functionally exercised. |
| Quartus | **13.0.1 Build 232, SP1 Web Edition**; installed under `C:\altera\13.0sp1\quartus`, not on PATH | Both `bin\quartus_sh.exe --version` and `bin64\quartus_sh.exe --version` succeeded. No analysis/synthesis was run. |
| VS Code | **1.136.1 x64** | `code --version` succeeded. |
| TerosHDL | **7.0.3**, extension `teros-technology.teroshdl` | Confirmed by `code --list-extensions --show-versions` and relevant local configuration. |
| Additional HDL editor extension | **mshr-h.veriloghdl 1.29.0** | Extension listing only; no language or simulation validation. |
| Git | **2.53.0.windows.2**, executable in `C:\Program Files\Git\cmd` | Version reporting succeeded; existing local author configuration is available for commits. |
| GitHub CLI | **2.97.0**, executable in the user's WinGet package directory | Version reporting succeeded. Remote/authentication operations were not needed or checked. |

Version reporting demonstrates that executables can start; it does **not** demonstrate HDL compilation, supported SystemVerilog/assertion features, elaboration, a working simulation license/session, or successful synthesis. Compatibility of the eventual coding style must be established with these installed versions in the simulation phase. No alternative simulator is required for the current work.

### ModelSim configuration

- Installation configuration exists at `C:\altera\13.0sp1\modelsim_ase\modelsim.ini`. Standard library mappings use `$MODEL_TECH`; `Resolution` is `ps` and `TranscriptFile` is `transcript`.
- No project `modelsim.ini`, mapped project `work` library, testbench, `.do` file, or waveform configuration exists.
- `MODELSIM` and `MTI_HOME` are unset in the inspected shell. The ModelSim executable directory is on PATH.
- A later simulation phase must explicitly create/map a local library and define SystemVerilog compilation, test selection, exit status, and waveform setup. The installation's library mappings do not constitute a project configuration.

### TerosHDL and VS Code configuration

- The installed extension's global settings file is `C:\Users\HP\.teroshdl2_config.json`.
- `tools.general.select_tool` is currently **`ghdl`**, with execution mode `cmd` and waveform viewer `tool`.
- `tools.modelsim.installation_path` and `tools.quartus.installation_path` are empty. ModelSim compile/simulation option arrays are empty.
- Verilog linting is `disabled`; the VHDL linter is `none`.
- `C:\Users\HP\.teroshdl2_prj.json` exists but contains no `pulse_clock` reference.
- Relevant VS Code user settings in `C:\Users\HP\AppData\Roaming\Code\User\settings.json` select TerosHDL as the Verilog formatter; no relevant simulator executable path was found there.

**Setup gap:** the global TerosHDL selection does not currently describe the requested ModelSim/SystemVerilog workflow. ModelSim can already be invoked from PATH. Later project setup should select ModelSim and define the PULSE file list without treating the existing GHDL selection as a project requirement. Global editor configuration was left unchanged during reconnaissance.

### Quartus configuration

`QUARTUS_ROOTDIR` is `C:\altera\13.0sp1\quartus`. There is no local project or device choice. The paths above document observations on this machine; they are not proposed hardcoded paths for future repository scripts. Device selection and synthesis constraints belong to later RTL analysis; physical implementation is outside the present scope.

## 4. Dependencies, missing components, and assumptions

Only Markdown editing and Git are needed for this phase. Later functional simulation needs the installed ModelSim tools and a validated compile/elaborate/run flow. Quartus is available for the subsequent synthesis-oriented review. No additional simulator, waveform viewer, firmware, vendor IP, board, physical sensor, or pump is required now.

Missing components are expected at this stage: approved timing/interface contracts; architecture and FSM specifications; RTL; self-checking testbenches; ModelSim scripts/waves; digital application models; a finalized integration contract; and synthesis/verification evidence. Their absence is not a failed test.

The important unknowns are the actual system clock/reset contract, sensor representation/domain and bounce duration, protection-window trigger/expected response/range, fault recovery policy, and any periodic-event consumer. They are tracked as Q-01 through Q-08 in [requirements](PULSE_REQUIREMENTS.md). Team-dependent agreements are **BLOCKED / REQUIRES TEAM INPUT**; clearly labeled provisional specifications can still be reviewed.

No prior file naming convention exists. The current documents follow the paths requested in §37. Future module/file naming and module boundaries remain architecture-phase decisions.

## 5. Files delivered and current status

| File | Purpose | Status |
| --- | --- | --- |
| [project_inventory.md](project_inventory.md) | Source/workspace/tool evidence, gaps, and scope | Reconnaissance complete; records pre-change state. |
| [PULSE_REQUIREMENTS.md](PULSE_REQUIREMENTS.md) | Classified requirements, ownership, assumptions, open questions | Draft for review. |
| [PULSE_TIMING_SPEC.md](PULSE_TIMING_SPEC.md) | Initial units, example durations/ranges, exact timing boundaries | Provisional proposal. |
| [PULSE_INTERFACE.md](PULSE_INTERFACE.md) | Initial PULSE-side ports and synchronous contract | Provisional; no other-team agreement claimed. |

No RTL, testbench, simulator script, application model, or hardware file is part of this delivery. No simulation, waveform, synthesis, resource, or physical timing result is claimed. Document review and arithmetic checks are the validation appropriate to this phase.

Next step: review this package, settle or explicitly accept its assumptions, then complete timing/interface decisions and move to architecture and state-machine design. The user's section 37 review stop applies before implementation.
