module pulse_top #(
    parameter integer TIMER_WIDTH = 32,
    parameter integer SENSOR_CHANNELS = 2,
    parameter integer DEBOUNCE_CYCLES = 1000000,
    parameter integer PERIOD_WIDTH = 32
) (
    input  wire                       clk,
    input  wire                       reset,
    input  wire                       enable,
    input  wire                       timer_start,
    input  wire                       timer_cancel,
    input  wire [TIMER_WIDTH-1:0]     cfg_timer_cycles,
    input  wire [SENSOR_CHANNELS-1:0] sensor_in,
    output wire                       timer_busy,
    output wire                       timer_done,
    output wire [SENSOR_CHANNELS-1:0] sensor_debounced,
    output wire [SENSOR_CHANNELS-1:0] sensor_valid,
    input  wire                       periodic_enable,
    input  wire [PERIOD_WIDTH-1:0]     cfg_period_cycles,
    output wire                       periodic_tick
);

    pulse_timer #(
        .TIMER_WIDTH(TIMER_WIDTH)
    ) u_timer (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .timer_start(timer_start),
        .timer_cancel(timer_cancel),
        .cfg_timer_cycles(cfg_timer_cycles),
        .timer_busy(timer_busy),
        .timer_done(timer_done)
    );

    pulse_periodic #(.PERIOD_WIDTH(PERIOD_WIDTH)) u_periodic (
        .clk(clk), .reset(reset), .enable(enable),
        .periodic_enable(periodic_enable),
        .cfg_period_cycles(cfg_period_cycles), .periodic_tick(periodic_tick)
    );

    // Each sensor progresses independently of both timing functions.
    genvar channel;
    generate
        for (channel = 0; channel < SENSOR_CHANNELS; channel = channel + 1) begin : gen_sensor
            pulse_debounce #(
                .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
            ) u_debounce (
                .clk(clk),
                .reset(reset),
                .enable(enable),
                .sensor_in(sensor_in[channel]),
                .sensor_debounced(sensor_debounced[channel]),
                .sensor_valid(sensor_valid[channel])
            );
        end
    endgenerate

    // synthesis translate_off
    initial begin
        if (TIMER_WIDTH < 1) begin
            $display("FAIL pulse_top: TIMER_WIDTH must be positive");
            $stop;
        end
        if (SENSOR_CHANNELS < 1) begin
            $display("FAIL pulse_top: SENSOR_CHANNELS must be positive");
            $stop;
        end
        if (DEBOUNCE_CYCLES < 1) begin
            $display("FAIL pulse_top: DEBOUNCE_CYCLES must be positive");
            $stop;
        end
    end
    // synthesis translate_on

endmodule
