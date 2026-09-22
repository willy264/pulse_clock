`timescale 1ns/1ps

module pulse_periodic_tb;
    reg clk = 1'b0;
    always #10 clk = ~clk;
    reg reset = 1'b1, enable = 1'b0, periodic_enable = 1'b0;
    reg [3:0] cfg_period_cycles = 4'd0;
    wire periodic_tick;
    reg tiny_reset = 1'b1, tiny_enable = 1'b0, tiny_periodic_enable = 1'b0;
    reg tiny_cfg = 1'b0;
    wire tiny_tick;
    reg wide_reset = 1'b1, wide_enable = 1'b0, wide_periodic_enable = 1'b0;
    reg [31:0] wide_cfg = 32'd0;
    wire wide_tick;
    wire [31:0] checker_errors, tiny_checker_errors, wide_checker_errors;
    wire checker_error, tiny_checker_error, wide_checker_error;
    integer test_passed = 0;
    integer checks = 0;
    integer cycle_number = 0;
    integer case_id = 0;
    integer n, elapsed, period, priority_case, abort_case, abort_edge;
    integer consumer_count = 0;
    integer expected_consumer_count = 0;
    reg previous_expected_tick = 1'b0;
    reg [3:0] live_cfg;

    pulse_periodic #(.PERIOD_WIDTH(4)) dut (
        .clk(clk), .reset(reset), .enable(enable),
        .periodic_enable(periodic_enable), .cfg_period_cycles(cfg_period_cycles),
        .periodic_tick(periodic_tick)
    );
    pulse_periodic #(.PERIOD_WIDTH(1)) tiny_dut (
        .clk(clk), .reset(tiny_reset), .enable(tiny_enable),
        .periodic_enable(tiny_periodic_enable), .cfg_period_cycles(tiny_cfg),
        .periodic_tick(tiny_tick)
    );
    pulse_periodic wide_dut (
        .clk(clk), .reset(wide_reset), .enable(wide_enable),
        .periodic_enable(wide_periodic_enable), .cfg_period_cycles(wide_cfg),
        .periodic_tick(wide_tick)
    );
    pulse_periodic_checker #(.PERIOD_WIDTH(4), .REPORT_ERRORS(1)) monitor (
        .clk(clk), .reset(reset), .enable(enable),
        .periodic_enable(periodic_enable), .cfg_period_cycles(cfg_period_cycles),
        .periodic_tick(periodic_tick), .error_count(checker_errors), .error_pulse(checker_error)
    );
    pulse_periodic_checker #(.PERIOD_WIDTH(1), .REPORT_ERRORS(1)) tiny_monitor (
        .clk(clk), .reset(tiny_reset), .enable(tiny_enable),
        .periodic_enable(tiny_periodic_enable), .cfg_period_cycles(tiny_cfg),
        .periodic_tick(tiny_tick), .error_count(tiny_checker_errors), .error_pulse(tiny_checker_error)
    );
    pulse_periodic_checker #(.PERIOD_WIDTH(32), .REPORT_ERRORS(1)) wide_monitor (
        .clk(clk), .reset(wide_reset), .enable(wide_enable),
        .periodic_enable(wide_periodic_enable), .cfg_period_cycles(wide_cfg),
        .periodic_tick(wide_tick), .error_count(wide_checker_errors), .error_pulse(wide_checker_error)
    );

    // A real consumer samples the previously registered tick on clk, exactly
    // like synchronous application logic. The tick is never used as a clock.
    always @(posedge clk) begin
        if (reset || !enable || !periodic_enable)
            consumer_count <= 0;
        else if (periodic_tick)
            consumer_count <= consumer_count + 1;
    end

    task automatic check(input condition, input [8*256-1:0] message_text);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL pulse_periodic_tb case O%02d cycle %0d: %0s", case_id, cycle_number, message_text);
                $stop;
            end
        end
    endtask

    task automatic step(
        input r, input en, input pe, input [3:0] cfg, input expected_tick
    );
        begin
            @(negedge clk);
            reset = r; enable = en; periodic_enable = pe; cfg_period_cycles = cfg;
            if (r || !en || !pe)
                expected_consumer_count = 0;
            else if (previous_expected_tick)
                expected_consumer_count = expected_consumer_count + 1;
            @(posedge clk); #2;
            cycle_number = cycle_number + 1;
            check(periodic_tick === expected_tick, "elapsed-edge event deadline and width");
            check(consumer_count === expected_consumer_count, "synchronous consumer samples prior-edge tick exactly once");
            check(checker_errors === 32'd0 && !checker_error, "independent modulo checker agrees");
            previous_expected_tick = expected_tick;
        end
    endtask

    task automatic tiny_step(input r, input en, input pe, input cfg, input expected_tick);
        begin
            @(negedge clk);
            tiny_reset = r; tiny_enable = en; tiny_periodic_enable = pe; tiny_cfg = cfg;
            @(posedge clk); #2;
            cycle_number = cycle_number + 1;
            check(tiny_tick === expected_tick, "width-one zero/one interval and disable behavior");
            check(tiny_checker_errors === 32'd0 && !tiny_checker_error, "minimum-width modulo checker agrees");
        end
    endtask

    task automatic wide_step(input r, input en, input pe, input [31:0] cfg, input expected_tick);
        begin
            @(negedge clk);
            wide_reset = r; wide_enable = en; wide_periodic_enable = pe; wide_cfg = cfg;
            @(posedge clk); #2;
            cycle_number = cycle_number + 1;
            check(wide_tick === expected_tick, "default-width elapsed-edge event deadline");
            check(wide_checker_errors === 32'd0 && !wide_checker_error, "default-width modulo checker agrees");
        end
    endtask

    initial begin
        // O01: Both enables are required; reset suppresses all requests.
        case_id = 1;
        step(1, 1, 1, 4'd1, 0);
        repeat (3) step(0, 0, 1, 4'd1, 0);
        repeat (3) step(0, 1, 0, 4'd1, 0);

        // O02: Exhaust every reduced-width setting for at least three periods.
        // The capture edge p0 is not elapsed time. Live values change on every
        // following edge, including reload edges, but never move the deadline.
        case_id = 2;
        for (n = 0; n < 16; n = n + 1) begin
            period = (n == 0) ? 1 : n;
            step(1, 0, 0, n[3:0], 0);
            step(0, 1, 1, n[3:0], 0);
            for (elapsed = 1; elapsed <= 3 * period + 1; elapsed = elapsed + 1) begin
                live_cfg = n + elapsed;
                step(0, 1, 1, live_cfg, (elapsed % period) == 0);
            end
            check(consumer_count == 3, "consumer receives three completed intervals after their registered edges");
            step(0, 1, 0, 4'd0, 0);
        end

        // O03: Each clearing control wins midway and on the expiration edge.
        // Release always captures a fresh changed period at p0, with no tick.
        case_id = 3;
        for (priority_case = 0; priority_case < 3; priority_case = priority_case + 1) begin
            for (abort_case = 0; abort_case < 2; abort_case = abort_case + 1) begin
                abort_edge = (abort_case == 0) ? 2 : 5;
                step(1, 1, 1, 4'd5, 0);
                step(0, 1, 1, 4'd5, 0);
                for (elapsed = 1; elapsed < abort_edge; elapsed = elapsed + 1)
                    step(0, 1, 1, 4'd1, 0);
                repeat (2) step(priority_case == 2, priority_case != 0,
                                priority_case != 1, 4'd1, 0);
                step(0, 1, 1, 4'd3, 0);
                for (elapsed = 1; elapsed <= 6; elapsed = elapsed + 1)
                    step(0, 1, 1, 4'd10, (elapsed % 3) == 0);
                step(1, 1, 1, 4'd1, 0);
            end
        end

        // O04: Minimum legal width, both values, consecutive P=1 events, and
        // local disable/reenable preserve the full first-interval convention.
        case_id = 4;
        step(1, 0, 0, 4'd0, 0);
        for (n = 0; n < 2; n = n + 1) begin
            tiny_step(1, 0, 0, n[0], 0);
            tiny_step(0, 1, 1, n[0], 0);
            repeat (4) tiny_step(0, 1, 1, !n[0], 1);
            tiny_step(0, 1, 0, n[0], 0);
            tiny_step(0, 1, 1, n[0], 0);
            repeat (3) tiny_step(0, 1, 1, !n[0], 1);
        end
        tiny_step(1, 0, 0, 0, 0);

        // O05: Default-width odd/even values and a value above eight bits.
        // Every selected period completes at least three unaccelerated times.
        case_id = 5;
        for (n = 0; n < 4; n = n + 1) begin
            case (n)
                0: period = 3;
                1: period = 4;
                2: period = 257;
                default: period = 1000;
            endcase
            wide_step(1, 0, 0, period, 0);
            wide_step(0, 1, 1, period, 0);
            for (elapsed = 1; elapsed <= 3 * period + 1; elapsed = elapsed + 1)
                wide_step(0, 1, 1, 32'd1, (elapsed % period) == 0);
            wide_step(0, 0, 1, 32'd1, 0);
        end

        // O06: Unsigned 32-bit maximum stays quiet over a bounded observation,
        // then aborts. This does not claim a full maximum-duration simulation.
        case_id = 6;
        wide_step(1, 0, 0, 32'd0, 0);
        wide_step(0, 1, 1, 32'hffff_ffff, 0);
        repeat (32) wide_step(0, 1, 1, 32'd0, 0);
        wide_step(0, 1, 0, 32'd2, 0);
        wide_step(0, 1, 1, 32'd2, 0);
        for (elapsed = 1; elapsed <= 6; elapsed = elapsed + 1)
            wide_step(0, 1, 1, 32'hffff_ffff, (elapsed % 2) == 0);
        wide_step(1, 0, 0, 32'd0, 0);

        // Deliberate negative runner probe, inactive in the normal regression.
        if ($test$plusargs("PULSE_INJECT_FAILURE"))
            check(1'b0, "intentional PULSE_INJECT_FAILURE before success marker");
        test_passed = 1;
        $display("PASS pulse_periodic_tb checks=%0d cycles=%0d cases=O01-O06", checks, cycle_number);
        $finish;
    end

    initial begin
        #1_000_000;
        $display("FAIL pulse_periodic_tb watchdog timeout");
        $stop;
    end
endmodule
