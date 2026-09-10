# Source from a writable build directory. Compatible with ModelSim Tcl 8.4.
onerror {quit -f -code 2}
set pulse_repo [file normalize [file join [file dirname [info script]] ..]]
if {![file exists modelsim.ini]} {vmap -c}
if {![file isdirectory work]} {vlib work}
vmap -modelsimini modelsim.ini work work
set pulse_sources [list \
    src/pulse_timer.sv \
    src/pulse_debounce.sv \
    src/pulse_top.sv \
    src/application/water_tank_controller.sv \
    tb/models/pump_model.sv \
    tb/models/water_tank_model.sv \
    tb/models/sensor_model.sv \
    tb/pulse_timer_tb.sv \
    tb/pulse_debounce_tb.sv \
    tb/pulse_top_tb.sv \
    tb/water_tank_system_tb.sv]
foreach pulse_source $pulse_sources {
    vlog -sv -work work [file join $pulse_repo $pulse_source]
}
echo "PULSE_COMPILE_OK"
