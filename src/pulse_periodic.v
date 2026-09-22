// OSC-CONTRACT-1: recurring registered clock-enable events, not a new clock.
// Capture at p0; first event follows P complete clk intervals at pP.
module pulse_periodic #(
    parameter integer PERIOD_WIDTH = 32
) (
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    enable,
    input  wire                    periodic_enable,
    input  wire [PERIOD_WIDTH-1:0] cfg_period_cycles,
    output reg                     periodic_tick
);
    localparam [PERIOD_WIDTH-1:0] COUNT_ONE = 1'b1;

    reg active;
    reg [PERIOD_WIDTH-1:0] captured_period;
    reg [PERIOD_WIDTH-1:0] remaining;

    always @(posedge clk) begin
        if (reset || !enable || !periodic_enable) begin
            active          <= 1'b0;
            captured_period <= {PERIOD_WIDTH{1'b0}};
            remaining       <= {PERIOD_WIDTH{1'b0}};
            periodic_tick   <= 1'b0;
        end else if (!active) begin
            active          <= 1'b1;
            captured_period <= (cfg_period_cycles == {PERIOD_WIDTH{1'b0}})
                ? COUNT_ONE : cfg_period_cycles;
            remaining       <= (cfg_period_cycles == {PERIOD_WIDTH{1'b0}})
                ? COUNT_ONE : cfg_period_cycles;
            periodic_tick   <= 1'b0;
        end else if (remaining == COUNT_ONE) begin
            // Reload the captured period; live configuration cannot move phase.
            remaining     <= captured_period;
            periodic_tick <= 1'b1;
        end else begin
            remaining     <= remaining - COUNT_ONE;
            periodic_tick <= 1'b0;
        end
    end

    // synthesis translate_off
    initial begin
        if (PERIOD_WIDTH < 1) begin
            $display("FAIL pulse_periodic: PERIOD_WIDTH must be positive");
            $stop;
        end
    end

    always @(posedge clk) begin
        if (((^{reset, enable, periodic_enable}) !== 1'bx) !== 1'b1) begin
            $display("FAIL pulse_periodic: unknown reset/enable/periodic_enable");
            $stop;
        end
        if (reset === 1'b0 && enable === 1'b1 && periodic_enable === 1'b1) begin
            if (((^{active, periodic_tick}) !== 1'bx) !== 1'b1) begin
                $display("FAIL pulse_periodic: unknown state/status");
                $stop;
            end
            if (active) begin
                if (((^{captured_period, remaining}) !== 1'bx &&
                     captured_period >= COUNT_ONE && remaining >= COUNT_ONE &&
                     remaining <= captured_period) !== 1'b1) begin
                    $display("FAIL pulse_periodic: invalid active period/count");
                    $stop;
                end
            end else begin
                if ((captured_period === {PERIOD_WIDTH{1'b0}} &&
                     remaining === {PERIOD_WIDTH{1'b0}} &&
                     periodic_tick === 1'b0) !== 1'b1) begin
                    $display("FAIL pulse_periodic: inactive state is not clear");
                    $stop;
                end
                if (((^cfg_period_cycles) !== 1'bx) !== 1'b1) begin
                    $display("FAIL pulse_periodic: unknown accepted configuration");
                    $stop;
                end
            end
        end
    end
    // synthesis translate_on
endmodule
