// Simulation-only predicates. A set noise-mask bit inverts that raw sensor.
module sensor_model #(
    parameter integer LOW_THRESHOLD = 25,
    parameter integer FULL_THRESHOLD = 90
) (
    input  wire signed [31:0] level,
    input  wire [1:0] noise_mask,
    output wire [1:0] sensor_out
);
    wire [1:0] ideal_sensors;
    assign ideal_sensors = {level >= FULL_THRESHOLD, level >= LOW_THRESHOLD};
    assign sensor_out = ideal_sensors ^ noise_mask;

    initial begin
        if ((LOW_THRESHOLD < 0) || (FULL_THRESHOLD > 100) ||
            (LOW_THRESHOLD >= FULL_THRESHOLD)) begin
            $display("FAIL sensor_model: thresholds must satisfy 0 <= LOW < FULL <= 100");
            $stop;
        end
    end
endmodule
