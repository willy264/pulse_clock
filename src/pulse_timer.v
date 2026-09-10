// One-shot elapsed interval. Counts full clk periods after an accepted start.
module pulse_timer #(
    parameter integer TIMER_WIDTH = 32
) (
    input  wire                   clk,
    input  wire                   reset,
    input  wire                   enable,
    input  wire                   timer_start,
    input  wire                   timer_cancel,
    input  wire [TIMER_WIDTH-1:0] cfg_timer_cycles,
    output reg                    timer_busy,
    output reg                    timer_done
);
    localparam [TIMER_WIDTH-1:0] COUNT_ONE = 1'b1;

    // Busy encodes IDLE/RUNNING; this downcounter also captures configuration.
    reg [TIMER_WIDTH-1:0] remaining;

    always @(posedge clk) begin
        if (reset) begin
            remaining  <= {TIMER_WIDTH{1'b0}};
            timer_busy <= 1'b0;
            timer_done <= 1'b0;
        end else if (!enable) begin
            remaining  <= {TIMER_WIDTH{1'b0}};
            timer_busy <= 1'b0;
            timer_done <= 1'b0;
        end else if (timer_cancel) begin
            remaining  <= {TIMER_WIDTH{1'b0}};
            timer_busy <= 1'b0;
            timer_done <= 1'b0;
        end else begin
            timer_done <= 1'b0;
            if (timer_busy) begin
                // Old busy wins over start, including on the expiry edge.
                if (remaining == COUNT_ONE) begin
                    remaining  <= {TIMER_WIDTH{1'b0}};
                    timer_busy <= 1'b0;
                    timer_done <= 1'b1;
                end else begin
                    remaining <= remaining - COUNT_ONE;
                end
            end else if (timer_start) begin
                remaining  <= (cfg_timer_cycles == {TIMER_WIDTH{1'b0}})
                    ? COUNT_ONE : cfg_timer_cycles;
                timer_busy <= 1'b1;
            end else begin
                remaining  <= {TIMER_WIDTH{1'b0}};
                timer_busy <= 1'b0;
            end
        end
    end

    // synthesis translate_off
    initial begin
        if (TIMER_WIDTH < 1) begin
            $display("FAIL pulse_timer: TIMER_WIDTH must be positive");
            $stop;
        end
    end

    always @(posedge clk) begin
        if (((^{reset, enable}) !== 1'bx) !== 1'b1) begin
            $display("FAIL pulse_timer: unknown reset/enable");
            $stop;
        end
        if (reset === 1'b0 && enable === 1'b1) begin
            if (((^{timer_start, timer_cancel, timer_busy, timer_done}) !== 1'bx) !== 1'b1) begin
                $display("FAIL pulse_timer: unknown control/state");
                $stop;
            end
            if ((!(timer_busy && timer_done)) !== 1'b1) begin
                $display("FAIL pulse_timer: busy and done overlap");
                $stop;
            end
            if (timer_busy) begin
                if (((^remaining) !== 1'bx && remaining != {TIMER_WIDTH{1'b0}}) !== 1'b1) begin
                    $display("FAIL pulse_timer: invalid active count");
                    $stop;
                end
            end else begin
                if ((remaining === {TIMER_WIDTH{1'b0}}) !== 1'b1) begin
                    $display("FAIL pulse_timer: idle count is not zero");
                    $stop;
                end
            end
            if (!timer_cancel && !timer_busy && timer_start) begin
                if (((^cfg_timer_cycles) !== 1'bx) !== 1'b1) begin
                    $display("FAIL pulse_timer: unknown accepted configuration");
                    $stop;
                end
            end
        end
    end
    // synthesis translate_on
endmodule
