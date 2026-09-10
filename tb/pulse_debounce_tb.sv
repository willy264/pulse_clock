`timescale 1ns/1ps
module pulse_debounce_tb;
    localparam integer D = 4;
    localparam integer DEFAULT_D = 1_000_000;
    logic clk = 1'b0;
    always #10 clk = ~clk;

    logic reset = 1'b1, enable = 1'b0, sensor_in = 1'b0;
    wire sensor_debounced, sensor_valid;
    logic min_reset = 1'b1, min_enable = 1'b0, min_input = 1'b0;
    wire min_output, min_valid;
    logic default_reset = 1'b1, default_enable = 1'b0, default_input = 1'b0;
    wire default_output, default_valid;
    wire maximum_output, maximum_valid;
    integer test_passed = 0;
    integer checks = 0;
    integer cycle_number = 0;
    integer k, width_index, phase;

    pulse_debounce #(.DEBOUNCE_CYCLES(D)) dut (
        .clk(clk), .reset(reset), .enable(enable), .sensor_in(sensor_in),
        .sensor_debounced(sensor_debounced), .sensor_valid(sensor_valid)
    );
    pulse_debounce #(.DEBOUNCE_CYCLES(1)) min_dut (
        .clk(clk), .reset(min_reset), .enable(min_enable), .sensor_in(min_input),
        .sensor_debounced(min_output), .sensor_valid(min_valid)
    );
    pulse_debounce default_dut (
        .clk(clk), .reset(default_reset), .enable(default_enable), .sensor_in(default_input),
        .sensor_debounced(default_output), .sensor_valid(default_valid)
    );
    // Elaboration/width boundary only: a full INT_MAX debounce is not simulated.
    pulse_debounce #(.DEBOUNCE_CYCLES(2_147_483_647)) maximum_dut (
        .clk(clk), .reset(1'b1), .enable(1'b0), .sensor_in(1'b0),
        .sensor_debounced(maximum_output), .sensor_valid(maximum_valid)
    );

    task automatic check(input logic condition, input string message_text);
        begin
            checks = checks + 1;
            if (condition !== 1'b1)
                $fatal(1, "pulse_debounce_tb cycle %0d: %s", cycle_number, message_text);
        end
    endtask

    task automatic step(input logic r, input logic en, input logic value);
        begin
            @(negedge clk);
            reset = r; enable = en; sensor_in = value;
            @(posedge clk); #1;
            cycle_number = cycle_number + 1;
        end
    endtask

    task automatic min_step(input logic r, input logic en, input logic value);
        begin
            @(negedge clk);
            min_reset = r; min_enable = en; min_input = value;
            @(posedge clk); #1;
            cycle_number = cycle_number + 1;
        end
    endtask

    task automatic default_step(input logic r, input logic en, input logic value);
        begin
            @(negedge clk);
            default_reset = r; default_enable = en; default_input = value;
            @(posedge clk); #1;
            cycle_number = cycle_number + 1;
        end
    endtask

    // Each deadline is relative to the first raw capture, not a copied FSM.
    task automatic startup(input logic value);
        integer elapsed;
        begin
            step(1, 1, value);
            check({sensor_valid, sensor_debounced} === 2'b00, "D01 reset clears channel");
            for (elapsed = 0; elapsed <= D + 2; elapsed = elapsed + 1) begin
                step(0, 1, value);
                if (elapsed < D + 2)
                    check({sensor_valid, sensor_debounced} === 2'b00,
                          "D01 startup stays invalid through synchronization and D full intervals");
                else
                    check({sensor_valid, sensor_debounced} === {1'b1, value},
                          "D01 qualifies on a(2+D), including zero startup");
            end
        end
    endtask

    task automatic stable_change(input logic old_value, input logic new_value);
        integer elapsed;
        begin
            for (elapsed = 0; elapsed <= D + 2; elapsed = elapsed + 1) begin
                step(0, 1, new_value);
                check(sensor_valid === 1'b1, "D02 validity remains sticky during change");
                if (elapsed < D + 2)
                    check(sensor_debounced === old_value, "D02 output waits D full intervals after synchronized sample");
                else
                    check(sensor_debounced === new_value, "D02 persistent change accepted at c(2+D)");
            end
        end
    endtask

    initial begin
        check($bits(dut.remaining) == 3, "D00 power-of-two D=4 inclusive count needs 3 bits");
        check($bits(min_dut.remaining) == 1, "D00 minimum D=1 count needs 1 bit");
        check($bits(default_dut.remaining) == 20, "D00 default D needs 20 bits");
        check($bits(maximum_dut.remaining) == 31, "D00 INT_MAX width arithmetic does not overflow");

        startup(0);
        stable_change(0, 1);
        stable_change(1, 0);
        startup(1);
        stable_change(1, 0);

        // D03: pulses of 1..D captured samples cannot qualify. Width D returns
        // on the candidate's exact expiry observation and must also be rejected.
        for (width_index = 1; width_index <= D; width_index = width_index + 1) begin
            for (k = 0; k < width_index; k = k + 1) begin
                step(0, 1, 1);
                check({sensor_valid, sensor_debounced} === 2'b10, "D03 short positive pulse rejected");
            end
            for (k = 0; k <= D + 2; k = k + 1) begin
                step(0, 1, 0);
                check({sensor_valid, sensor_debounced} === 2'b10, "D03 return/mismatch at expiry keeps accepted zero");
            end
        end
        stable_change(0, 1);
        for (k = 0; k < D; k = k + 1) begin
            step(0, 1, 0);
            check({sensor_valid, sensor_debounced} === 2'b11, "D04 short negative pulse rejected");
        end
        for (k = 0; k <= D + 2; k = k + 1) begin
            step(0, 1, 1);
            check({sensor_valid, sensor_debounced} === 2'b11, "D04 negative expiry-edge mismatch keeps accepted one");
        end
        stable_change(1, 0);

        // D05: repeated chatter does not erase the previously qualified reading.
        for (k = 0; k < 24; k = k + 1) begin
            step(0, 1, !k[0]);
            check({sensor_valid, sensor_debounced} === 2'b10, "D05 alternating chatter rejected with validity retained");
        end
        for (k = 0; k <= D + 2; k = k + 1) begin
            step(0, 1, 0);
            check({sensor_valid, sensor_debounced} === 2'b10, "D05 chatter settles without spurious acceptance");
        end
        // A pending candidate, a return, and a fresh candidate each restart time.
        step(0, 1, 1);
        step(0, 1, 1);
        step(0, 1, 0);
        for (k = 0; k <= D + 2; k = k + 1) begin
            step(0, 1, 1);
            check(sensor_valid === 1'b1, "D05 interrupted candidate retains valid");
            check(sensor_debounced === (k == D + 2), "D05 final candidate gets a new complete interval");
        end

        // D06: reset and disable while verifying invalidate and restart acquisition.
        for (phase = 0; phase < 2; phase = phase + 1) begin
            startup(0);
            step(0, 1, 1); // c0 capture
            step(0, 1, 1); // c1 synchronize
            step(0, 1, 1); // c2 observe candidate and load D
            step(phase == 0, phase != 1, 1);
            check({sensor_valid, sensor_debounced} === 2'b00, "D06 reset/disable clears a pending qualification");
            for (k = 0; k <= D + 2; k = k + 1) begin
                step(0, 1, 1);
                check(sensor_valid === (k == D + 2), "D06 re-enable/reset release starts full acquisition");
                check(sensor_debounced === (k == D + 2), "D06 no stale candidate survives clear");
            end
        end
        step(0, 0, 1);
        check({sensor_valid, sensor_debounced} === 2'b00, "D06 disable clears a qualified one");
        step(0, 0, 0);
        check({sensor_valid, sensor_debounced} === 2'b00, "D06 disabled input changes ignored");
        for (k = 0; k <= D + 2; k = k + 1) begin
            step(0, 1, 0);
            check(sensor_valid === (k == D + 2), "D06 zero needs fresh qualification after disable");
            check(sensor_debounced === 1'b0, "D06 re-enabled zero output preserved");
        end

        // D07: minimum D=1 needs two matching observations after synchronization.
        min_step(1, 1, 1);
        for (k = 0; k <= 3; k = k + 1) begin
            min_step(0, 1, 1);
            check({min_valid, min_output} === ((k == 3) ? 2'b11 : 2'b00),
                  "D07 minimum startup qualifies at a3, not a2");
        end
        min_step(0, 1, 0); // Single captured low: mismatch returns on its expiry.
        check({min_valid, min_output} === 2'b11, "D07 one-sample low waits for synchronization");
        for (k = 0; k < 5; k = k + 1) begin
            min_step(0, 1, 1);
            check({min_valid, min_output} === 2'b11, "D07 one-sample pulse rejected at minimum expiry");
        end
        for (k = 0; k <= 3; k = k + 1) begin
            min_step(0, 1, 0);
            check(min_valid === 1'b1, "D07 minimum validity retained");
            check(min_output === (k != 3), "D07 minimum falling change deadline");
        end
        min_step(0, 0, 0);
        check({min_valid, min_output} === 2'b00, "D07 minimum disable clears validity");
        for (k = 0; k <= 3; k = k + 1) begin
            min_step(0, 1, 0);
            check(min_valid === (k == 3), "D07 minimum zero still needs fresh full interval");
            check(min_output === 1'b0, "D07 minimum zero output");
        end

        // D08: full unaccelerated default debounce, 1,000,000 intervals at 50 MHz.
        // This is 20 ms of qualification plus two acquisition periods after a0.
        default_step(1, 1, 1);
        for (k = 0; k <= DEFAULT_D + 2; k = k + 1) begin
            default_step(0, 1, 1);
            check({default_valid, default_output} ===
                  ((k == DEFAULT_D + 2) ? 2'b11 : 2'b00),
                  "D08 default duration exact startup deadline");
        end
        default_step(0, 1, 1);
        check({default_valid, default_output} === 2'b11, "D08 default qualified output remains stable");

        test_passed = 1;
        $display("PASS pulse_debounce_tb checks=%0d cycles=%0d", checks, cycle_number);
        $finish;
    end

    initial begin
        #30_000_000;
        $fatal(1, "pulse_debounce_tb watchdog timeout");
    end
endmodule
