# Analysis and synthesis only: no fitter, pin assignment, programming, or hardware.
load_package flow
set pulse_repo [file normalize [lindex $argv 0]]
set pulse_top [lindex $argv 1]
set pulse_device [lindex $argv 2]
if {[lsearch -exact [list pulse_top water_tank_controller] $pulse_top] < 0} {
    error "Unsupported synthesis top: $pulse_top"
}
project_new $pulse_top -overwrite
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE $pulse_device
set_global_assignment -name TOP_LEVEL_ENTITY $pulse_top
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
foreach pulse_source [list src/pulse_timer.sv src/pulse_debounce.sv src/pulse_top.sv src/application/water_tank_controller.sv] {
    set_global_assignment -name SYSTEMVERILOG_FILE [file join $pulse_repo $pulse_source]
}
set_global_assignment -name SDC_FILE [file join $pulse_repo synth pulse.sdc]
export_assignments
execute_module -tool map
project_close
puts "PULSE_SYNTHESIS_OK $pulse_top"
