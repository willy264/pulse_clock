`timescale 1ns/1ps

// Test the checker independently: no pulse_periodic DUT is instantiated.
// Every tick value below is a predetermined good or intentionally bad sample.
module pulse_periodic_checker_tb;
    reg clk = 1'b0;
    always #10 clk = ~clk;
    reg reset = 1'b1, enable = 1'b0, periodic_enable = 1'b0;
    reg [3:0] cfg_period_cycles = 4'd0;
    reg sampled_tick = 1'b0;
    wire [31:0] error_count;
    wire error_pulse;
    integer expected_errors = 0;
    integer test_passed = 0;
    integer checks = 0;
    integer cycle_number = 0;
    integer case_id = 0;

    pulse_periodic_checker #(.PERIOD_WIDTH(4), .REPORT_ERRORS(0)) checker (
        .clk(clk), .reset(reset), .enable(enable), .periodic_enable(periodic_enable),
        .cfg_period_cycles(cfg_period_cycles), .periodic_tick(sampled_tick),
        .error_count(error_count), .error_pulse(error_pulse)
    );

    task automatic check(input condition, input [8*256-1:0] message_text);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL pulse_periodic_checker_tb case C%02d cycle %0d: %0s",
                         case_id, cycle_number, message_text);
                $stop;
            end
        end
    endtask

    task automatic sample_edge(
        input r, input en, input pe, input [3:0] cfg,
        input value, input integer expected_new_errors
    );
        begin
            @(negedge clk);
            reset = r; enable = en; periodic_enable = pe;
            cfg_period_cycles = cfg; sampled_tick = value;
            expected_errors = expected_errors + expected_new_errors;
            @(posedge clk); #2;
            cycle_number = cycle_number + 1;
            check(error_count === expected_errors, "checker counts precisely the scheduled violations");
            check(error_pulse === (expected_new_errors != 0), "checker error pulse identifies only the bad edge");
        end
    endtask

    initial begin
        // C01: Legal P=3, ignored live configuration, global/local clearing.
        case_id = 1;
        sample_edge(1, 1, 1, 4'd3, 0, 0);
        sample_edge(0, 1, 1, 4'd3, 0, 0); // p0
        sample_edge(0, 1, 1, 4'd1, 0, 0); // p1
        sample_edge(0, 1, 1, 4'd2, 0, 0); // p2
        sample_edge(0, 1, 1, 4'd4, 1, 0); // p3
        sample_edge(0, 1, 1, 4'd4, 0, 0); // p4
        sample_edge(0, 1, 1, 4'd4, 0, 0); // p5
        sample_edge(0, 1, 1, 4'd4, 1, 0); // p6
        sample_edge(0, 0, 1, 4'd4, 0, 0);
        sample_edge(0, 1, 0, 4'd4, 0, 0);

        // C02: Zero normalizes to one; P=1 stays high after p1, without gaps.
        case_id = 2;
        sample_edge(0, 1, 1, 4'd0, 0, 0);
        sample_edge(0, 1, 1, 4'd8, 1, 0);
        sample_edge(0, 1, 1, 4'd8, 1, 0);
        sample_edge(1, 1, 1, 4'd1, 0, 0);
        sample_edge(0, 1, 1, 4'd1, 0, 0);
        sample_edge(0, 1, 1, 4'd0, 1, 0);
        sample_edge(0, 1, 1, 4'd0, 1, 0);

        // C03: An early tick at p1 cannot move the independent p4 deadline.
        case_id = 3;
        sample_edge(1, 1, 1, 4'd4, 0, 0);
        sample_edge(0, 1, 1, 4'd4, 0, 0);
        sample_edge(0, 1, 1, 4'd4, 1, 1);
        sample_edge(0, 1, 1, 4'd4, 0, 0);
        sample_edge(0, 1, 1, 4'd4, 0, 0);
        sample_edge(0, 1, 1, 4'd4, 1, 0);

        // C04: A late pulse fails on both its missed and its late edge.
        case_id = 4;
        sample_edge(1, 1, 1, 4'd3, 0, 0);
        sample_edge(0, 1, 1, 4'd3, 0, 0);
        sample_edge(0, 1, 1, 4'd3, 0, 0);
        sample_edge(0, 1, 1, 4'd3, 0, 0);
        sample_edge(0, 1, 1, 4'd3, 0, 1);
        sample_edge(0, 1, 1, 4'd3, 1, 1);

        // C05: P>1 requires a one-cycle pulse, so an extra high is rejected.
        case_id = 5;
        sample_edge(1, 1, 1, 4'd2, 0, 0);
        sample_edge(0, 1, 1, 4'd2, 0, 0);
        sample_edge(0, 1, 1, 4'd2, 0, 0);
        sample_edge(0, 1, 1, 4'd2, 1, 0);
        sample_edge(0, 1, 1, 4'd2, 1, 1);
        sample_edge(0, 1, 1, 4'd2, 1, 0);

        // C06: Reset/global/local clear suppress events; reenable is p0 again.
        case_id = 6;
        sample_edge(1, 1, 1, 4'd3, 1, 1);
        sample_edge(0, 1, 1, 4'd3, 0, 0);
        sample_edge(0, 0, 1, 4'd3, 1, 1);
        sample_edge(0, 1, 0, 4'd3, 1, 1);
        sample_edge(0, 1, 1, 4'd3, 1, 1); // illegal capture-edge event
        sample_edge(0, 1, 1, 4'd3, 0, 0);
        sample_edge(0, 1, 1, 4'd3, 0, 0);
        sample_edge(0, 1, 1, 4'd3, 1, 0);

        // C07: Four-state comparison catches an unknown output as a failure.
        case_id = 7;
        sample_edge(1, 1, 1, 4'd3, 0, 0);
        sample_edge(0, 1, 1, 4'd3, 0, 0);
        sample_edge(0, 1, 1, 4'd3, 1'bx, 1);
        sample_edge(0, 1, 1, 4'd3, 0, 0);
        sample_edge(0, 1, 1, 4'd3, 1, 0);
        sample_edge(1, 0, 0, 4'd0, 0, 0);
        check(expected_errors == 9, "all nine predetermined bad samples were detected");

        test_passed = 1;
        $display("PASS pulse_periodic_checker_tb checks=%0d cycles=%0d expected_errors=%0d cases=C01-C07",
                 checks, cycle_number, expected_errors);
        $finish;
    end

    initial begin
        #100_000;
        $display("FAIL pulse_periodic_checker_tb watchdog timeout");
        $stop;
    end
endmodule
