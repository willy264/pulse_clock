onerror {quit -f -code 2}
# ModelSim 10.1d also invokes onbreak for a normal $finish. Resume the
# macro, then require the explicit success marker; $fatal leaves it zero.
onbreak {resume}
set pulse_tests [list pulse_timer_tb pulse_debounce_tb pulse_top_tb water_tank_system_tb]
set pulse_tb pulse_top_tb
if {[info exists env(PULSE_TESTBENCH)]} {set pulse_tb $env(PULSE_TESTBENCH)}
if {[lsearch -exact $pulse_tests $pulse_tb] < 0} {
    puts stderr "Unsupported PULSE_TESTBENCH: $pulse_tb"
    quit -f -code 2
}
# Keep internal signals observable for waveform review on the installed 10.1d tool.
vsim -novopt -onfinish stop -modelsimini modelsim.ini -wlf ${pulse_tb}.wlf work.$pulse_tb
log -r /*
if {$pulse_tb eq "water_tank_system_tb"} {
    vcd file water_tank_system.vcd
    vcd add -r /*
}
run -all
set pulse_passed [string trim [examine -radix decimal sim:/$pulse_tb/test_passed]]
if {$pulse_passed ne "1"} {
    puts stderr "FAIL $pulse_tb: test did not reach its success marker"
    quit -f -code 4
}
echo "PULSE_TEST_OK $pulse_tb"
quit -f -code 0
