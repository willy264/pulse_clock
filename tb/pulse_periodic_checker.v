`timescale 1ns/1ps

// Simulation-only OSC-CONTRACT-1 checker. Expected events come from elapsed
// sampling-edge timestamps modulo the captured period, never DUT internals.
module pulse_periodic_checker #(
    parameter integer PERIOD_WIDTH = 32,
    parameter integer REPORT_ERRORS = 0
) (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire periodic_enable,
    input wire [PERIOD_WIDTH-1:0] cfg_period_cycles,
    input wire periodic_tick,
    output integer error_count,
    output reg error_pulse
);
    localparam integer TIMESTAMP_WIDTH = PERIOD_WIDTH + 32;
    localparam [TIMESTAMP_WIDTH-1:0] ONE = 1'b1;
    reg [TIMESTAMP_WIDTH-1:0] edge_number;
    reg [TIMESTAMP_WIDTH-1:0] capture_edge;
    reg [TIMESTAMP_WIDTH-1:0] captured_period;
    reg active;
    reg expected_tick;
    reg invalid_input;

    initial begin
        edge_number = {TIMESTAMP_WIDTH{1'b0}};
        capture_edge = {TIMESTAMP_WIDTH{1'b0}};
        captured_period = ONE;
        active = 1'b0;
        expected_tick = 1'b0;
        invalid_input = 1'b0;
        error_count = 0;
        error_pulse = 1'b0;
    end

    always @(posedge clk) begin
        edge_number = edge_number + ONE;
        invalid_input = 1'b0;
        expected_tick = 1'b0;
        if ((^{reset, enable, periodic_enable}) === 1'bx) begin
            invalid_input = 1'b1;
            active = 1'b0;
        end else if (reset || !enable || !periodic_enable) begin
            active = 1'b0;
        end else if (!active) begin
            if ((^cfg_period_cycles) === 1'bx) begin
                invalid_input = 1'b1;
            end else begin
                captured_period = (cfg_period_cycles == {PERIOD_WIDTH{1'b0}})
                    ? ONE : cfg_period_cycles;
                capture_edge = edge_number;
                active = 1'b1;
            end
        end else begin
            expected_tick = ((edge_number - capture_edge) % captured_period) == 0;
        end

        // Observe after the DUT's nonblocking updates. Stimulus must meet
        // setup at the sampling edge and remain stable through this delay.
        #1;
        error_pulse = invalid_input || (periodic_tick !== expected_tick);
        if (error_pulse) begin
            error_count = error_count + 1;
            if (REPORT_ERRORS) begin
                $display("FAIL pulse_periodic_checker edge %0d: tick=%b expected=%b invalid_input=%b",
                         edge_number, periodic_tick, expected_tick, invalid_input);
                $stop;
            end
        end
    end
endmodule
