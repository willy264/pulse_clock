`timescale 1ns/1ps

// Developer smoke checks for OSC-CONTRACT-1. The independent unit suite
// supplies broader boundary coverage; this bench is reproducible on its own.
module pulse_periodic_smoke_tb;
    reg clk = 1'b0;
    reg reset = 1'b1;
    reg enable = 1'b0;
    reg periodic_enable = 1'b0;
    reg [7:0] cfg_period_cycles = 8'd0;
    wire periodic_tick;

    integer test_passed = 0;
    integer checks = 0;
    integer cycle_number = 0;
    integer elapsed;

    always #10 clk = ~clk;

    pulse_periodic #(.PERIOD_WIDTH(8)) dut (
        .clk(clk), .reset(reset), .enable(enable),
        .periodic_enable(periodic_enable),
        .cfg_period_cycles(cfg_period_cycles), .periodic_tick(periodic_tick)
    );

    task automatic step(
        input r, input en, input pen, input [7:0] cfg,
        input expected_tick, input [8*256-1:0] message_text
    );
        begin
            @(negedge clk);
            reset = r;
            enable = en;
            periodic_enable = pen;
            cfg_period_cycles = cfg;
            @(posedge clk); #1;
            cycle_number = cycle_number + 1;
            checks = checks + 1;
            if (periodic_tick !== expected_tick) begin
                $display("FAIL pulse_periodic_smoke_tb cycle %0d: %0s; tick=%b expected=%b",
                         cycle_number, message_text, periodic_tick, expected_tick);
                $stop;
            end
        end
    endtask

    initial begin
        step(1, 1, 1, 8'd3, 0, "reset inhibits startup");
        step(0, 1, 1, 8'd3, 0, "P=3 capture edge p0 has no tick");
        // Three pulses at p3/p6/p9; changed live configuration stays ignored.
        for (elapsed = 1; elapsed <= 11; elapsed = elapsed + 1)
            step(0, 1, 1, 8'd1, elapsed % 3 == 0, "captured P=3 repeats without phase drift");
        step(0, 1, 0, 8'd3, 0, "local disable at p12 suppresses expiry");
        step(0, 1, 0, 8'd2, 0, "local disable holds output clear");

        step(0, 1, 1, 8'd2, 0, "local re-enable captures P=2 at fresh p0");
        step(0, 1, 1, 8'd2, 0, "P=2 p1 waits");
        step(0, 1, 1, 8'd2, 1, "P=2 p2 ticks");
        step(0, 1, 1, 8'd2, 0, "P=2 pulse is one interval wide");
        step(0, 0, 1, 8'd2, 0, "global disable on next expiry suppresses tick");
        step(0, 0, 1, 8'd0, 0, "global disable ignores configuration changes");

        step(0, 1, 1, 8'd0, 0, "zero captures as P=1, with no p0 tick");
        for (elapsed = 1; elapsed <= 4; elapsed = elapsed + 1)
            step(0, 1, 1, 8'd7, 1, "normalized P=1 stays high across event cycles");
        step(1, 1, 1, 8'd4, 0, "reset suppresses P=1 expiry and clears phase");

        step(0, 1, 1, 8'd4, 0, "reset release captures fresh P=4");
        step(0, 1, 1, 8'd4, 0, "P=4 p1 waits");
        step(0, 1, 1, 8'd4, 0, "P=4 p2 waits");
        step(0, 1, 0, 8'd1, 0, "local disable aborts partial interval");
        step(0, 1, 1, 8'd1, 0, "P=1 re-enable requires a new full first interval");
        step(0, 1, 1, 8'd1, 1, "explicit P=1 first event");
        step(0, 1, 1, 8'd1, 1, "explicit P=1 repeated event");
        step(0, 1, 0, 8'd1, 0, "local disable clears a high tick");

        test_passed = 1;
        $display("PASS pulse_periodic_smoke_tb checks=%0d cycles=%0d", checks, cycle_number);
        $finish;
    end

    initial begin
        #100000;
        $display("FAIL pulse_periodic_smoke_tb watchdog timeout");
        $stop;
    end
endmodule
