`timescale 1ns/1ps

module pulse_top_tb;
    localparam integer TIMER_WIDTH = 8;
    localparam integer SENSOR_CHANNELS = 2;
    localparam integer DEBOUNCE_CYCLES = 3;
    localparam integer SENSOR_DELAY = DEBOUNCE_CYCLES + 2;

    reg clk = 1'b0;
    reg reset = 1'b1;
    reg enable = 1'b0;
    reg timer_start = 1'b0;
    reg timer_cancel = 1'b0;
    reg [TIMER_WIDTH-1:0] cfg_timer_cycles = {TIMER_WIDTH{1'b0}};
    reg [SENSOR_CHANNELS-1:0] sensor_in = {SENSOR_CHANNELS{1'b0}};
    wire timer_busy;
    wire timer_done;
    wire [SENSOR_CHANNELS-1:0] sensor_debounced;
    wire [SENSOR_CHANNELS-1:0] sensor_valid;

    integer edge_count = 0;
    integer test_passed = 0;
    integer first_capture;
    integer sensor_deadline;
    integer timer_deadline;
    integer step;

    pulse_top #(
        .TIMER_WIDTH(TIMER_WIDTH),
        .SENSOR_CHANNELS(SENSOR_CHANNELS),
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
    ) dut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .timer_start(timer_start),
        .timer_cancel(timer_cancel),
        .cfg_timer_cycles(cfg_timer_cycles),
        .sensor_in(sensor_in),
        .timer_busy(timer_busy),
        .timer_done(timer_done),
        .sensor_debounced(sensor_debounced),
        .sensor_valid(sensor_valid)
    );

    always #10 clk = ~clk;
    always @(posedge clk) edge_count = edge_count + 1;

    // A 256-byte packed vector carries every diagnostic without truncation.
    task automatic check(input condition, input [8*256-1:0] message);
        if (condition !== 1'b1) begin
            $display("FAIL pulse_top_tb edge %0d: %0s", edge_count, message);
            $stop;
        end
    endtask

    task automatic expect_outputs(
        input expected_busy,
        input expected_done,
        input [SENSOR_CHANNELS-1:0] expected_sensor,
        input [SENSOR_CHANNELS-1:0] expected_valid,
        input [8*256-1:0] scenario
    );
        if ({timer_busy, timer_done, sensor_debounced, sensor_valid} !==
            {expected_busy, expected_done, expected_sensor, expected_valid}) begin
            $display("FAIL pulse_top_tb edge %0d (%0s): busy/done/sensor/valid %b/%b/%b/%b, expected %b/%b/%b/%b",
                edge_count, scenario, timer_busy, timer_done, sensor_debounced,
                sensor_valid, expected_busy, expected_done, expected_sensor, expected_valid);
            $stop;
        end
    endtask

    // Drive off the sampling edge, then observe only after registered updates.
    task automatic drive_edge(
        input next_reset,
        input next_enable,
        input next_start,
        input next_cancel,
        input [TIMER_WIDTH-1:0] next_cycles,
        input [SENSOR_CHANNELS-1:0] next_sensor
    );
        begin
            @(negedge clk);
            reset = next_reset;
            enable = next_enable;
            timer_start = next_start;
            timer_cancel = next_cancel;
            cfg_timer_cycles = next_cycles;
            sensor_in = next_sensor;
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        drive_edge(1, 0, 0, 0, 8'd0, 2'b00);
        expect_outputs(0, 0, 2'b00, 2'b00, "sampled reset");

        // P01: Even zero-valued sensors need acquisition plus the full interval.
        drive_edge(0, 1, 0, 0, 8'd0, 2'b00);
        first_capture = edge_count;
        sensor_deadline = first_capture + SENSOR_DELAY;
        expect_outputs(0, 0, 2'b00, 2'b00, "first enabled zero capture");
        while (edge_count < sensor_deadline) begin
            drive_edge(0, 1, 0, 0, 8'd0, 2'b00);
            expect_outputs(0, 0, 2'b00,
                (edge_count == sensor_deadline) ? 2'b11 : 2'b00,
                "zero startup qualification deadline");
        end

        // P02: Channel 0 chatters while channel 1 rises and an 18-cycle window runs.
        // Deadlines are measured from external capture/start timestamps.
        drive_edge(0, 1, 1, 0, 8'd18, 2'b11);
        first_capture = edge_count;
        sensor_deadline = first_capture + SENSOR_DELAY;
        timer_deadline = first_capture + 18;
        expect_outputs(1, 0, 2'b00, 2'b11, "concurrent start");
        while (edge_count < timer_deadline) begin
            step = edge_count - first_capture + 1;
            drive_edge(0, 1, 0, 0, 8'd1,
                (step % 2 == 0) ? 2'b11 : 2'b10);
            expect_outputs(edge_count < timer_deadline,
                edge_count == timer_deadline,
                (edge_count >= sensor_deadline) ? 2'b10 : 2'b00,
                2'b11, "independent timer and sensor channels");
        end
        for (step = 0; step < SENSOR_DELAY + 1; step = step + 1) begin
            drive_edge(0, 1, 0, 0, 8'd1, 2'b10);
            expect_outputs(0, 0, 2'b10, 2'b11, "chatter ends; done clears");
        end

        // P03: Cancellation must neither invalidate nor restart an active qualifier.
        drive_edge(0, 1, 1, 0, 8'd12, 2'b00);
        first_capture = edge_count;
        sensor_deadline = first_capture + SENSOR_DELAY;
        timer_deadline = first_capture + 12;
        expect_outputs(1, 0, 2'b10, 2'b11, "start before cancellation");
        while (edge_count <= timer_deadline) begin
            step = edge_count - first_capture + 1;
            drive_edge(0, 1, 0, step == 2, 8'd12, 2'b00);
            expect_outputs(step < 2, 0,
                (edge_count >= sensor_deadline) ? 2'b00 : 2'b10,
                2'b11, "cancel leaves qualifier deadline and validity intact");
        end

        // P04: Both qualified outputs and timer_done must survive a shared edge.
        drive_edge(0, 1, 1, 0, 8'd5, 2'b11);
        first_capture = edge_count;
        sensor_deadline = first_capture + SENSOR_DELAY;
        timer_deadline = first_capture + 5;
        check(sensor_deadline == timer_deadline, "fixture must align deadlines");
        expect_outputs(1, 0, 2'b00, 2'b11, "aligned operation starts");
        while (edge_count < timer_deadline) begin
            drive_edge(0, 1, 0, 0, 8'd5, 2'b11);
            expect_outputs(edge_count < timer_deadline,
                edge_count == timer_deadline,
                (edge_count == sensor_deadline) ? 2'b11 : 2'b00,
                2'b11, "simultaneous qualification and expiry");
        end
        drive_edge(0, 1, 0, 0, 8'd5, 2'b11);
        expect_outputs(0, 0, 2'b11, 2'b11, "aligned completion pulse clears");

        // P05: Reset interrupts both an active timer and a pending sensor change.
        drive_edge(0, 1, 1, 0, 8'd20, 2'b00);
        expect_outputs(1, 0, 2'b11, 2'b11, "work before reset");
        repeat (2) drive_edge(0, 1, 0, 0, 8'd20, 2'b00);
        drive_edge(1, 1, 1, 0, 8'd20, 2'b00);
        expect_outputs(0, 0, 2'b00, 2'b00, "reset clears all channels and timer");
        drive_edge(0, 1, 0, 0, 8'd20, 2'b11);
        sensor_deadline = edge_count + SENSOR_DELAY;
        expect_outputs(0, 0, 2'b00, 2'b00, "reset recovery first capture");
        while (edge_count < sensor_deadline) begin
            drive_edge(0, 1, 0, 0, 8'd20, 2'b11);
            expect_outputs(0, 0,
                (edge_count == sensor_deadline) ? 2'b11 : 2'b00,
                (edge_count == sensor_deadline) ? 2'b11 : 2'b00,
                "reset requires fresh qualification");
        end

        // P06: Disable is an abort, including acquisition; no old work resumes.
        drive_edge(0, 1, 1, 0, 8'd20, 2'b00);
        expect_outputs(1, 0, 2'b11, 2'b11, "work before disable");
        drive_edge(0, 1, 0, 0, 8'd20, 2'b00);
        drive_edge(0, 0, 1, 0, 8'd1, 2'b11);
        expect_outputs(0, 0, 2'b00, 2'b00, "global disable aborts and invalidates");
        repeat (3) begin
            drive_edge(0, 0, 1, 0, 8'd1, 2'b11);
            expect_outputs(0, 0, 2'b00, 2'b00, "disabled starts ignored");
        end
        drive_edge(0, 1, 0, 0, 8'd1, 2'b11);
        sensor_deadline = edge_count + SENSOR_DELAY;
        expect_outputs(0, 0, 2'b00, 2'b00, "reenable first capture");
        while (edge_count < sensor_deadline) begin
            drive_edge(0, 1, 0, 0, 8'd1, 2'b11);
            expect_outputs(0, 0,
                (edge_count == sensor_deadline) ? 2'b11 : 2'b00,
                (edge_count == sensor_deadline) ? 2'b11 : 2'b00,
                "reenable requires fresh qualification without timer restart");
        end
        // P07: Wait beyond the aborted deadline to prove there is no resume.
        repeat (21) begin
            drive_edge(0, 1, 0, 0, 8'd1, 2'b11);
            expect_outputs(0, 0, 2'b11, 2'b11, "aborted work never resumes");
        end

        test_passed = 1;
        $display("PASS pulse_top_tb: concurrent timing, qualification, cancellation, reset, and disable");
        $finish;
    end

    initial begin
        #100000;
        $display("FAIL pulse_top_tb watchdog expired");
        $stop;
    end
endmodule
