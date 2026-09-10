// Simulation-only unitless tank. Every STEP_CYCLES clocks integrates one
// fill/drain step and saturates to [0,100]. This is not a hydraulic model.
module water_tank_model #(
    parameter integer STEP_CYCLES = 5,
    parameter integer FILL_PER_STEP = 10,
    parameter integer DRAIN_PER_STEP = 2,
    parameter integer INITIAL_LEVEL = 0
) (
    input  wire clk,
    input  wire reset,
    input  wire flow_present,
    input  wire drain_enable,
    output integer level
);
    integer step_count;
    integer proposed_level;

    initial begin
        if ((STEP_CYCLES < 1) || (FILL_PER_STEP < 0) ||
            (DRAIN_PER_STEP < 0) || (INITIAL_LEVEL < 0) || (INITIAL_LEVEL > 100)) begin
            $display("FAIL water_tank_model: invalid model parameter");
            $stop;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            step_count <= 0;
            level <= INITIAL_LEVEL;
        end else if (step_count == STEP_CYCLES - 1) begin
            step_count <= 0;
            proposed_level = level;
            if (flow_present)
                proposed_level = proposed_level + FILL_PER_STEP;
            if (drain_enable)
                proposed_level = proposed_level - DRAIN_PER_STEP;
            if (proposed_level > 100)
                level <= 100;
            else if (proposed_level < 0)
                level <= 0;
            else
                level <= proposed_level;
        end else begin
            step_count <= step_count + 1;
        end
    end
endmodule
