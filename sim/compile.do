# Source from a writable build directory. Compatible with ModelSim Tcl 8.4.
onerror {quit -f -code 2}
set pulse_repo [file normalize [file join [file dirname [info script]] ..]]
if {![file exists modelsim.ini]} {vmap -c}
if {![file isdirectory work]} {vlib work}
vmap -modelsimini modelsim.ini work work
set pulse_sources [list \
    src/pulse_timer.v \
    src/pulse_debounce.v \
    src/pulse_periodic.v \
    src/pulse_top.v \
    src/application/water_tank_controller.v \
    tb/models/pump_model.v \
    tb/models/water_tank_model.v \
    tb/models/sensor_model.v \
    tb/pulse_timer_tb.v \
    tb/pulse_debounce_tb.v \
    tb/pulse_top_tb.v \
    tb/pulse_periodic_smoke_tb.v \
    tb/pulse_periodic_checker.v \
    tb/pulse_periodic_checker_tb.v \
    tb/pulse_periodic_tb.v \
    tb/water_tank_system_tb.v]
foreach pulse_source $pulse_sources {
    vlog -vlog01compat -work work [file join $pulse_repo $pulse_source]
}
echo "PULSE_COMPILE_OK"
