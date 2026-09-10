# Illustrative 50 MHz clock from A-01. No board or I/O timing is specified.
create_clock -name clk -period 20.000 [get_ports {clk}]
