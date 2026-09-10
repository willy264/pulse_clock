// One-shot elapsed interval. Counts full clk periods after an accepted start.
module pulse_timer #(
    parameter integer TIMER_WIDTH = 32
) (
    input  logic                   clk,
    input  logic                   reset,
    input  logic                   enable,
    input  logic                   timer_start,
    input  logic                   timer_cancel,
    input  logic [TIMER_WIDTH-1:0] cfg_timer_cycles,
    output logic                   timer_busy,
    output logic                   timer_done
);
    localparam logic [TIMER_WIDTH-1:0] COUNT_ONE = 1'b1;

    // Busy encodes IDLE/RUNNING; this downcounter also captures configuration.
    logic [TIMER_WIDTH-1:0] remaining;

    always_ff @(posedge clk) begin
        if (reset) begin
            remaining  <= '0;
            timer_busy <= 1'b0;
            timer_done <= 1'b0;
        end else if (!enable) begin
            remaining  <= '0;
            timer_busy <= 1'b0;
            timer_done <= 1'b0;
        end else if (timer_cancel) begin
            remaining  <= '0;
            timer_busy <= 1'b0;
            timer_done <= 1'b0;
        end else begin
            timer_done <= 1'b0;
            if (timer_busy) begin
                // Old busy wins over start, including on the expiry edge.
                if (remaining == COUNT_ONE) begin
                    remaining  <= '0;
                    timer_busy <= 1'b0;
                    timer_done <= 1'b1;
                end else begin
                    remaining <= remaining - COUNT_ONE;
                end
            end else if (timer_start) begin
                remaining  <= (cfg_timer_cycles == '0)
                    ? COUNT_ONE : cfg_timer_cycles;
                timer_busy <= 1'b1;
            end else begin
                remaining  <= '0;
                timer_busy <= 1'b0;
            end
        end
    end

    // synthesis translate_off
    initial begin
        if (TIMER_WIDTH < 1)
            $fatal(1, "pulse_timer: TIMER_WIDTH must be positive");
    end

    always @(posedge clk) begin
        assert ((^{reset, enable}) !== 1'bx)
            else $fatal(1, "pulse_timer: unknown reset/enable");
        if (reset === 1'b0 && enable === 1'b1) begin
            assert ((^{timer_start, timer_cancel, timer_busy, timer_done}) !== 1'bx)
                else $fatal(1, "pulse_timer: unknown control/state");
            assert (!(timer_busy && timer_done))
                else $fatal(1, "pulse_timer: busy and done overlap");
            if (timer_busy)
                assert ((^remaining) !== 1'bx && remaining != '0)
                    else $fatal(1, "pulse_timer: invalid active count");
            else
                assert (remaining === {TIMER_WIDTH{1'b0}})
                    else $fatal(1, "pulse_timer: idle count is not zero");
            if (!timer_cancel && !timer_busy && timer_start)
                assert ((^cfg_timer_cycles) !== 1'bx)
                    else $fatal(1, "pulse_timer: unknown accepted configuration");
        end
    end
    // synthesis translate_on
endmodule
