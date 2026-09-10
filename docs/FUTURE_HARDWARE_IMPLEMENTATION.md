# Future hardware implementation

Physical implementation has not started. The current deliverable is reusable RTL, digital models, simulation, and synthesis-oriented analysis.

## Path from this baseline

```mermaid
flowchart LR
    RTL[Reviewed RTL and simulation] --> Agree[Agree clock / sensors / protection policy]
    Agree --> Synth[Board-specific synthesis and timing checks]
    Synth --> FPGA[FPGA prototype]
    FPGA --> Sensors[Physical level sensing integration]
    Sensors --> Driver[Pump driver integration]
    Driver --> Tank[Controlled physical tank validation]
```

First settle Q-01…Q-08: clock frequency/tolerance, reset distribution, sensor polarity/encoding and ownership of synchronization, measured noise durations, expected process response, acceptable window/error, event transport, and recovery policy. Replace illustrative cycle values and unitless model assumptions using that evidence.

Select an actual FPGA/board only when that phase is authorized. Regenerate cycle settings and constraints for its real clock. Recheck counter capacity, input/reset clock-domain crossings, synchronizer stage count/MTBF, and end-to-end latency including debounce and GUARDIAN. The representative Quartus analysis part is not an approved board choice, and pre-fit synthesis does not prove timing closure.

Physical sensors and a pump driver require appropriate electrical interfaces and a separately reviewed system design. No pinout, mains wiring, driver circuit, calibration, or physical protection claim is supplied here. Initial tests should connect the FPGA to a controlled digital source before integrating physical equipment.

Reuse the existing tests as regression requirements while adding board timing, physical noise/response measurements, and agreed fault/recovery scenarios. ASIC-oriented reuse likewise requires a suitable synthesis flow, constraints, CDC/reset analysis, and technology-specific validation; successful Quartus parsing is not an ASIC sign-off.
