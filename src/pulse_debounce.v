// One independent Boolean channel: synchronization then D full stable intervals.
module pulse_debounce #(
    parameter integer DEBOUNCE_CYCLES = 1_000_000
) (
    input  wire clk,
    input  wire reset,
    input  wire enable,
    input  wire sensor_in,
    output reg  sensor_debounced,
    output reg  sensor_valid
);
    // Bits needed for the inclusive range [0, max_count], at least one.
    // Shifting the positive value avoids overflow at INT_MAX + 1.
    function integer inclusive_count_width;
        input integer max_count;
        integer shifted_count;
        begin
            inclusive_count_width = 1;
            shifted_count = max_count;
            while (shifted_count > 1) begin
                inclusive_count_width = inclusive_count_width + 1;
                shifted_count = shifted_count >> 1;
            end
        end
    endfunction

    localparam integer COUNTER_WIDTH = inclusive_count_width(DEBOUNCE_CYCLES);
    localparam [COUNTER_WIDTH-1:0] RELOAD_COUNT =
        DEBOUNCE_CYCLES[COUNTER_WIDTH-1:0];
    localparam [COUNTER_WIDTH-1:0] COUNT_ONE = 1'b1;

    localparam [1:0] WAIT_SAMPLE = 2'b00;
    localparam [1:0] VERIFYING   = 2'b01;
    localparam [1:0] STABLE      = 2'b10;

    reg [1:0] state;
    reg sync_stage1, sync_stage2;
    reg ready_stage1, ready_stage2;
    reg candidate;
    reg [COUNTER_WIDTH-1:0] remaining;

    always @(posedge clk) begin
        if (reset || !enable) begin
            sync_stage1     <= 1'b0;
            sync_stage2     <= 1'b0;
            ready_stage1    <= 1'b0;
            ready_stage2    <= 1'b0;
            state           <= WAIT_SAMPLE;
            candidate       <= 1'b0;
            remaining       <= {COUNTER_WIDTH{1'b0}};
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
                    remaining        <= {COUNTER_WIDTH{1'b0}};
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
                        remaining        <= {COUNTER_WIDTH{1'b0}};
                        sensor_debounced <= candidate;
                        sensor_valid     <= 1'b1;
                        state            <= STABLE;
                    end else begin
                        remaining <= remaining - COUNT_ONE;
                    end
                end
                STABLE: begin
                    remaining <= {COUNTER_WIDTH{1'b0}};
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
                    remaining        <= {COUNTER_WIDTH{1'b0}};
                    sensor_debounced <= 1'b0;
                    sensor_valid     <= 1'b0;
                end
            endcase
        end
    end

    // synthesis translate_off
    initial begin
        if (DEBOUNCE_CYCLES < 1) begin
            $display("FAIL pulse_debounce: DEBOUNCE_CYCLES must be positive");
            $stop;
        end
    end

    always @(posedge clk) begin
        if (((^{reset, enable}) !== 1'bx) !== 1'b1) begin
            $display("FAIL pulse_debounce: unknown reset/enable");
            $stop;
        end
        if (reset === 1'b0 && enable === 1'b1) begin
            if (((^{state, ready_stage1, ready_stage2,
                       sensor_debounced, sensor_valid}) !== 1'bx) !== 1'b1) begin
                $display("FAIL pulse_debounce: unknown state/status");
                $stop;
            end
            if (ready_stage2) begin
                if (((^sync_stage2) !== 1'bx) !== 1'b1) begin
                    $display("FAIL pulse_debounce: unknown observed sensor");
                    $stop;
                end
            end
            if (state == VERIFYING) begin
                if ((ready_stage2 && remaining >= COUNT_ONE && remaining <= RELOAD_COUNT) !== 1'b1) begin
                    $display("FAIL pulse_debounce: invalid verification count/readiness");
                    $stop;
                end
            end else if (state == WAIT_SAMPLE || state == STABLE) begin
                if ((remaining == {COUNTER_WIDTH{1'b0}}) !== 1'b1) begin
                    $display("FAIL pulse_debounce: inactive count is not zero");
                    $stop;
                end
            end
            if (state == STABLE) begin
                if ((ready_stage2 && sensor_valid && candidate == sensor_debounced) !== 1'b1) begin
                    $display("FAIL pulse_debounce: invalid stable state");
                    $stop;
                end
            end
        end
    end
    // synthesis translate_on
endmodule
