module pulse_top #(
    parameter integer TIMER_WIDTH = 32,
    parameter integer SENSOR_CHANNELS = 2,
    parameter integer DEBOUNCE_CYCLES = 1000000
) (
    input  logic                       clk,
    input  logic                       reset,
    input  logic                       enable,
    input  logic                       timer_start,
    input  logic                       timer_cancel,
    input  logic [TIMER_WIDTH-1:0]     cfg_timer_cycles,
    input  logic [SENSOR_CHANNELS-1:0] sensor_in,
    output logic                       timer_busy,
    output logic                       timer_done,
    output logic [SENSOR_CHANNELS-1:0] sensor_debounced,
    output logic [SENSOR_CHANNELS-1:0] sensor_valid
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

    // Each sensor progresses independently of the one-shot and other channels.
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
        if (TIMER_WIDTH < 1)
            $fatal(1, "pulse_top: TIMER_WIDTH must be positive");
        if (SENSOR_CHANNELS < 1)
            $fatal(1, "pulse_top: SENSOR_CHANNELS must be positive");
        if (DEBOUNCE_CYCLES < 1)
            $fatal(1, "pulse_top: DEBOUNCE_CYCLES must be positive");
    end
    // synthesis translate_on

endmodule
