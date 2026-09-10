// Simulation-only digital pump model: no electrical or hydraulic dynamics.
// Its net ports and continuous assignments already use Verilog-2001 syntax.
module pump_model (
    input  wire command_enable,
    input  wire source_available,
    output wire running,
    output wire flow_present
);
    assign running = command_enable;
    assign flow_present = command_enable && source_available;
endmodule
