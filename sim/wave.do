# Run after loading a testbench, or after opening its saved WLF dataset in the GUI.
onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -divider "Testbench controls and application status"
add wave -radix unsigned /*/*
add wave -divider "PULSE and controller internals"
add wave -r -radix unsigned /*/dut/*
configure wave -timelineunits ns
update
wave zoom full
