`timescale 1ns/1ps
module pulse_timer_tb;
    reg clk = 1'b0;
    always #10 clk = ~clk; // 50 MHz fixture; counts remain cycle based.

    reg reset = 1'b1, enable = 1'b0;
    reg timer_start = 1'b0, timer_cancel = 1'b0;
    reg [7:0] cfg_timer_cycles = 8'd0;
    wire timer_busy, timer_done;
    wire tiny_busy, tiny_done;
    reg wide_reset = 1'b1, wide_enable = 1'b0;
    reg wide_start = 1'b0, wide_cancel = 1'b0;
    reg [31:0] wide_cfg = 32'd0;
    wire wide_busy, wide_done;
    integer test_passed = 0;
    integer checks = 0;
    integer cycle_number = 0;
    integer n, elapsed, duration, priority_case;

    pulse_timer #(.TIMER_WIDTH(8)) dut (
        .clk(clk), .reset(reset), .enable(enable),
        .timer_start(timer_start), .timer_cancel(timer_cancel),
        .cfg_timer_cycles(cfg_timer_cycles),
        .timer_busy(timer_busy), .timer_done(timer_done)
    );
    pulse_timer #(.TIMER_WIDTH(1)) tiny_dut (
        .clk(clk), .reset(reset), .enable(enable),
        .timer_start(timer_start), .timer_cancel(timer_cancel),
        .cfg_timer_cycles(cfg_timer_cycles[0]),
        .timer_busy(tiny_busy), .timer_done(tiny_done)
    );
    pulse_timer wide_dut (
        .clk(clk), .reset(wide_reset), .enable(wide_enable),
        .timer_start(wide_start), .timer_cancel(wide_cancel),
        .cfg_timer_cycles(wide_cfg),
        .timer_busy(wide_busy), .timer_done(wide_done)
    );

    // A 256-byte packed vector carries every diagnostic without truncation.
    task automatic check(input condition, input [8*256-1:0] message_text);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL pulse_timer_tb cycle %0d: %0s", cycle_number, message_text);
                $stop;
            end
        end
    endtask

    task automatic step(
        input r, input en, input st, input ca,
        input [7:0] cfg
    );
        begin
            @(negedge clk);
            reset = r; enable = en; timer_start = st;
            timer_cancel = ca; cfg_timer_cycles = cfg;
            @(posedge clk); #1;
            cycle_number = cycle_number + 1;
        end
    endtask

    task automatic wide_step(
        input r, input en, input st, input ca,
        input [31:0] cfg
    );
        begin
            @(negedge clk);
            wide_reset = r; wide_enable = en; wide_start = st;
            wide_cancel = ca; wide_cfg = cfg;
            @(posedge clk); #1;
            cycle_number = cycle_number + 1;
        end
    endtask

    initial begin
        step(1, 0, 1, 1, 8'd255);
        check({timer_busy, timer_done} === 2'b00, "T01 reset outranks every control");
        step(0, 0, 1, 0, 8'd255);
        check({timer_busy, timer_done} === 2'b00, "T01 disabled start ignored");
        step(0, 1, 1, 1, 8'd255);
        check({timer_busy, timer_done} === 2'b00, "T01 cancel inhibits idle start");

        // T02: public output deadlines exhaust every 8-bit configuration.
        // N=0 is one interval; the start edge never counts as elapsed time.
        for (n = 0; n < 256; n = n + 1) begin
            duration = (n == 0) ? 1 : n;
            step(0, 1, 1, 0, n[7:0]);
            check({timer_busy, timer_done} === 2'b10, "T02 accepted start");
            check({tiny_busy, tiny_done} === 2'b10, "T03 width-one accepted start");
            for (elapsed = 1; elapsed <= duration; elapsed = elapsed + 1) begin
                step(0, 1, 0, 0, ~n[7:0]);
                check(timer_busy === (elapsed < duration), "T02 exact busy deadline");
                check(timer_done === (elapsed == duration), "T02 exact done deadline");
                if (elapsed == 1)
                    check({tiny_busy, tiny_done} === 2'b01, "T03 both width-one values expire at e1");
                else
                    check({tiny_busy, tiny_done} === 2'b00, "T03 width-one done clears");
            end
            step(0, 1, 0, 0, 8'd0);
            check({timer_busy, timer_done} === 2'b00, "T02 done is one cycle, no automatic restart");
            check({tiny_busy, tiny_done} === 2'b00, "T03 minimum-width event clears");
        end

        // T04: ignore busy starts/configuration changes, including the final edge.
        step(0, 1, 1, 0, 8'd4);
        step(0, 1, 1, 0, 8'd1);
        check({timer_busy, timer_done} === 2'b10, "T04 busy start ignored at e1");
        step(0, 1, 0, 0, 8'd255);
        check({timer_busy, timer_done} === 2'b10, "T04 configuration does not alter active deadline");
        step(0, 1, 1, 0, 8'd0);
        check({timer_busy, timer_done} === 2'b10, "T04 still busy at e3");
        step(0, 1, 1, 0, 8'd8);
        check({timer_busy, timer_done} === 2'b01, "T04 start on expiry ignored");
        step(0, 1, 1, 0, 8'd2);
        check({timer_busy, timer_done} === 2'b10, "T04 next edge accepts new configuration");
        step(0, 1, 0, 0, 8'd255);
        check({timer_busy, timer_done} === 2'b10, "T04 new interval has one elapsed cycle");
        step(0, 1, 0, 0, 8'd255);
        check({timer_busy, timer_done} === 2'b01, "T04 second interval uses new captured value");
        step(0, 1, 0, 0, 8'd0);

        // T05: a held request starts again on the next eligible idle edge.
        step(0, 1, 1, 0, 8'd2);
        step(0, 1, 1, 0, 8'd2);
        check({timer_busy, timer_done} === 2'b10, "T05 held start does not restart active timer");
        step(0, 1, 1, 0, 8'd2);
        check({timer_busy, timer_done} === 2'b01, "T05 held start does not prevent expiry");
        step(0, 1, 1, 0, 8'd2);
        check({timer_busy, timer_done} === 2'b10, "T05 held start accepted in idle");
        step(0, 1, 0, 0, 8'd2);
        step(0, 1, 0, 0, 8'd2);
        check({timer_busy, timer_done} === 2'b01, "T05 repeated interval completes");
        step(0, 1, 0, 0, 8'd0);

        // T06: each abort control has priority over expiry and simultaneous start.
        for (priority_case = 0; priority_case < 3; priority_case = priority_case + 1) begin
            step(0, 1, 1, 0, 8'd3);
            step(0, 1, 0, 0, 8'd3);
            step(0, 1, 0, 0, 8'd3);
            check({timer_busy, timer_done} === 2'b10, "T06 still active one edge before expiry");
            step(priority_case == 2, priority_case != 1, 1, priority_case == 0, 8'd9);
            check({timer_busy, timer_done} === 2'b00, "T06 abort on expiry suppresses completion/start");
            step(0, 1, 0, 0, 8'd9);
            check({timer_busy, timer_done} === 2'b00, "T06 release does not resume or queue");
        end
        step(0, 1, 1, 0, 8'd8);
        step(0, 1, 0, 1, 8'd8);
        check({timer_busy, timer_done} === 2'b00, "T06 early cancel aborts");
        step(0, 1, 1, 1, 8'd8);
        check({timer_busy, timer_done} === 2'b00, "T06 held cancel inhibits repeated start");
        step(0, 1, 1, 0, 8'd8);
        step(1, 1, 0, 0, 8'd8);
        check({timer_busy, timer_done} === 2'b00, "T06 reset during count aborts");
        step(0, 1, 1, 0, 8'd8);
        step(0, 0, 0, 0, 8'd8);
        check({timer_busy, timer_done} === 2'b00, "T06 disable during count aborts");
        step(0, 1, 0, 0, 8'd8);
        check({timer_busy, timer_done} === 2'b00, "T06 re-enable remains idle");

        // T07: default 32-bit maximum is sampled/decremented/cancelled.
        // This deliberately does not wait all 4,294,967,295 periods.
        wide_step(1, 0, 0, 0, 32'd0);
        wide_step(0, 1, 1, 0, 32'hffff_ffff);
        check({wide_busy, wide_done} === 2'b10, "T07 maximum 32-bit start");
        check(wide_dut.remaining === 32'hffff_ffff, "T07 maximum captured without overflow");
        wide_step(0, 1, 0, 0, 32'd1);
        check(wide_dut.remaining === 32'hffff_fffe, "T07 maximum decrements unsigned");
        wide_step(0, 1, 0, 1, 32'd0);
        check({wide_busy, wide_done} === 2'b00, "T07 maximum operation cancels");
        check(wide_dut.remaining === 32'd0, "T07 cancellation clears maximum count");

        // T08: default-width representative durations complete at their deadlines.
        wide_step(0, 1, 1, 0, 32'd0);
        wide_step(0, 1, 0, 0, 32'd999);
        check({wide_busy, wide_done} === 2'b01, "T08 default-width zero normalizes to one");
        wide_step(0, 1, 1, 0, 32'd1000);
        for (elapsed = 1; elapsed <= 1000; elapsed = elapsed + 1) begin
            wide_step(0, 1, 0, 0, 32'd1);
            check(wide_busy === (elapsed < 1000), "T08 representative busy deadline");
            check(wide_done === (elapsed == 1000), "T08 representative completion deadline");
        end
        wide_step(0, 1, 0, 0, 32'd0);
        check({wide_busy, wide_done} === 2'b00, "T08 default-width completion clears");
        wide_step(0, 1, 1, 0, 32'd250_000_000);
        check(wide_dut.remaining === 32'd250_000_000, "T08 5 s configuration fits and captures");
        wide_step(0, 1, 0, 0, 32'd0);
        check(wide_dut.remaining === 32'd249_999_999, "T08 5 s configuration decrements");
        wide_step(0, 1, 0, 1, 32'd0);
        check({wide_busy, wide_done} === 2'b00, "T08 illustrative window cancels");

        test_passed = 1;
        $display("PASS pulse_timer_tb checks=%0d cycles=%0d", checks, cycle_number);
        $finish;
    end

    initial begin
        #2_000_000;
        $display("FAIL pulse_timer_tb watchdog timeout");
        $stop;
    end
endmodule
