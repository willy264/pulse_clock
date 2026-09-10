// One independent Boolean channel: synchronization then D full stable intervals.
module pulse_debounce #(
    parameter integer DEBOUNCE_CYCLES = 1_000_000
) (
    input  logic clk,
    input  logic reset,
    input  logic enable,
    input  logic sensor_in,
    output logic sensor_debounced,
    output logic sensor_valid
);
    // The 33-bit intermediate prevents signed integer overflow at INT_MAX + 1.
    localparam integer COUNTER_WIDTH = (DEBOUNCE_CYCLES < 1) ? 1 :
        $clog2({1'b0, DEBOUNCE_CYCLES} + 33'd1);
    localparam logic [COUNTER_WIDTH-1:0] RELOAD_COUNT =
        DEBOUNCE_CYCLES[COUNTER_WIDTH-1:0];
    localparam logic [COUNTER_WIDTH-1:0] COUNT_ONE = 1'b1;

    typedef enum logic [1:0] {
        WAIT_SAMPLE = 2'b00,
        VERIFYING   = 2'b01,
        STABLE      = 2'b10
    } qualification_state_t;

    qualification_state_t state;
    logic sync_stage1, sync_stage2;
    logic ready_stage1, ready_stage2;
    logic candidate;
    logic [COUNTER_WIDTH-1:0] remaining;

    always_ff @(posedge clk) begin
        if (reset || !enable) begin
            sync_stage1     <= 1'b0;
            sync_stage2     <= 1'b0;
            ready_stage1    <= 1'b0;
            ready_stage2    <= 1'b0;
            state           <= WAIT_SAMPLE;
            candidate       <= 1'b0;
            remaining       <= '0;
            sensor_debounced <= 1'b0;
            sensor_valid    <= 1'b0;
        end else begin
            sync_stage1  <= sensor_in;
            sync_stage2  <= sync_stage1;
            ready_stage1 <= 1'b1;
            ready_stage2 <= ready_stage1;

            case (state)
                WAIT_SAMPLE: begin
                    candidate        <= 1'b0;
                    remaining        <= '0;
                    sensor_debounced <= 1'b0;
                    sensor_valid     <= 1'b0;
                    // Old readiness excludes reset padding in both stages.
                    if (ready_stage2) begin
                        candidate <= sync_stage2;
                        remaining <= RELOAD_COUNT;
                        state     <= VERIFYING;
                    end
                end
                VERIFYING: begin
                    // Mismatch outranks expiry, including on its final edge.
                    if (sync_stage2 != candidate) begin
                        candidate <= sync_stage2;
                        remaining <= RELOAD_COUNT;
                    end else if (remaining == COUNT_ONE) begin
                        remaining        <= '0;
                        sensor_debounced <= candidate;
                        sensor_valid     <= 1'b1;
                        state            <= STABLE;
                    end else begin
                        remaining <= remaining - COUNT_ONE;
                    end
                end
                STABLE: begin
                    remaining <= '0;
                    if (sync_stage2 != candidate) begin
                        candidate <= sync_stage2;
                        remaining <= RELOAD_COUNT;
                        state     <= VERIFYING;
                    end
                end
                default: begin
                    // An unused encoding restarts only this channel.
                    sync_stage1      <= 1'b0;
                    sync_stage2      <= 1'b0;
                    ready_stage1     <= 1'b0;
                    ready_stage2     <= 1'b0;
                    state            <= WAIT_SAMPLE;
                    candidate        <= 1'b0;
                    remaining        <= '0;
                    sensor_debounced <= 1'b0;
                    sensor_valid     <= 1'b0;
                end
            endcase
        end
    end

    // synthesis translate_off
    initial begin
        if (DEBOUNCE_CYCLES < 1)
            $fatal(1, "pulse_debounce: DEBOUNCE_CYCLES must be positive");
    end

    always @(posedge clk) begin
        assert ((^{reset, enable}) !== 1'bx)
            else $fatal(1, "pulse_debounce: unknown reset/enable");
        if (reset === 1'b0 && enable === 1'b1) begin
            assert ((^{state, ready_stage1, ready_stage2,
                       sensor_debounced, sensor_valid}) !== 1'bx)
                else $fatal(1, "pulse_debounce: unknown state/status");
            if (ready_stage2)
                assert ((^sync_stage2) !== 1'bx)
                    else $fatal(1, "pulse_debounce: unknown observed sensor");
            if (state == VERIFYING) begin
                assert (ready_stage2 && remaining >= COUNT_ONE && remaining <= RELOAD_COUNT)
                    else $fatal(1, "pulse_debounce: invalid verification count/readiness");
            end else if (state == WAIT_SAMPLE || state == STABLE) begin
                assert (remaining == '0)
                    else $fatal(1, "pulse_debounce: inactive count is not zero");
            end
            if (state == STABLE)
                assert (ready_stage2 && sensor_valid && candidate == sensor_debounced)
                    else $fatal(1, "pulse_debounce: invalid stable state");
        end
    end
    // synthesis translate_on
endmodule
