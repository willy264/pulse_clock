// Provisional GUARDIAN demonstration policy; see docs/WATER_TANK_BEHAVIOR.md.
module water_tank_controller #(
    parameter integer TIMER_WIDTH = 32,
    parameter integer DEBOUNCE_CYCLES = 1000000
) (
    input  wire                        clk,
    input  wire                        reset,
    input  wire                        enable,
    input  wire                        fault_clear,
    input  wire [1:0]                 sensor_in,
    input  wire [TIMER_WIDTH-1:0]     cfg_protection_cycles,
    output wire                        pump_enable,
    output wire                        dry_run_detected,
    output wire                        protection_active,
    output wire [1:0]                 sensor_debounced,
    output wire [1:0]                 sensor_valid,
    output wire                        timer_busy,
    output wire                        timer_done
);
    localparam [1:0] IDLE          = 2'b00;
    localparam [1:0] WAIT_RESPONSE = 2'b01;
    localparam [1:0] FILLING       = 2'b10;
    localparam [1:0] PROTECTED     = 2'b11;

    reg [1:0] state, next_state;
    reg timer_start;
    reg timer_cancel;
    wire readings_usable;

    assign readings_usable = (&sensor_valid) && (sensor_debounced != 2'b10);
    assign pump_enable = (state == WAIT_RESPONSE) || (state == FILLING);
    assign dry_run_detected = (state == PROTECTED);
    assign protection_active = (state == PROTECTED);

    pulse_top #(
        .TIMER_WIDTH(TIMER_WIDTH),
        .SENSOR_CHANNELS(2),
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
    ) pulse (
        .clk(clk), .reset(reset), .enable(enable),
        .timer_start(timer_start), .timer_cancel(timer_cancel),
        .cfg_timer_cycles(cfg_protection_cycles),
        .timer_busy(timer_busy), .timer_done(timer_done),
        .sensor_in(sensor_in), .sensor_debounced(sensor_debounced),
        .sensor_valid(sensor_valid)
    );

    // Combinational strobes let PULSE accept the start on the same edge
    // that the state register enables the pump. Registered strobes would
    // introduce an extra, undocumented protection-window delay.
    always @(*) begin
        next_state = state;
        timer_start = 1'b0;
        timer_cancel = 1'b0;
        case (state)
            IDLE: begin
                if (readings_usable && (sensor_debounced == 2'b00)) begin
                    next_state = WAIT_RESPONSE;
                    timer_start = 1'b1;
                end
            end
            WAIT_RESPONSE: begin
                // Qualified response and invalid readings outrank timeout.
                if (!readings_usable || (sensor_debounced == 2'b11)) begin
                    next_state = IDLE;
                    timer_cancel = 1'b1;
                end else if (sensor_debounced == 2'b01) begin
                    next_state = FILLING;
                    timer_cancel = 1'b1;
                end else if (timer_done) begin
                    next_state = PROTECTED;
                end
            end
            FILLING: begin
                timer_cancel = 1'b1;
                if (!readings_usable || (sensor_debounced == 2'b11))
                    next_state = IDLE;
            end
            PROTECTED: begin
                timer_cancel = 1'b1;
                if (fault_clear)
                    next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
                timer_cancel = 1'b1;
            end
        endcase
    end

    always @(posedge clk) begin
        if (reset || !enable)
            state <= IDLE;
        else
            state <= next_state;
    end
endmodule
