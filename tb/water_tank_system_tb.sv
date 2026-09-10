`timescale 1ns/1ps

// Accelerated fixture: 50 MHz, debounce 3 cycles (60 ns), protection 64
// cycles (1.28 us), tank steps every 5 clocks. These are not field timings.
module water_tank_system_tb;
    localparam integer TIMER_WIDTH = 8;
    localparam integer D = 3;
    localparam integer WINDOW = 64;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic enable = 1'b1;
    logic fault_clear = 1'b0;
    logic model_reset = 1'b1;
    logic source_available = 1'b1;
    logic drain_enable = 1'b0;
    logic [1:0] noise_mask = 2'b00;
    logic direct_sensors = 1'b0;
    logic [1:0] directed_value = 2'b00;
    logic [TIMER_WIDTH-1:0] cfg_protection_cycles = WINDOW;
    wire [1:0] modeled_sensors;
    wire [1:0] sensor_in;
    wire [1:0] sensor_debounced, sensor_valid;
    wire pump_enable, dry_run_detected, protection_active;
    wire timer_busy, timer_done, pump_running, flow_present;
    wire signed [31:0] tank_level;

    integer test_passed = 0;
    integer check_count = 0;
    integer cycle_count = 0;
    integer start_cycle;
    integer i;

    always #10 clk = ~clk;
    always @(posedge clk) cycle_count = cycle_count + 1;

    assign sensor_in = direct_sensors ? directed_value : modeled_sensors;

    water_tank_controller #(.TIMER_WIDTH(TIMER_WIDTH), .DEBOUNCE_CYCLES(D)) dut (
        .clk(clk), .reset(reset), .enable(enable), .fault_clear(fault_clear),
        .sensor_in(sensor_in), .cfg_protection_cycles(cfg_protection_cycles),
        .pump_enable(pump_enable), .dry_run_detected(dry_run_detected),
        .protection_active(protection_active), .sensor_debounced(sensor_debounced),
        .sensor_valid(sensor_valid), .timer_busy(timer_busy), .timer_done(timer_done)
    );
    pump_model pump (.command_enable(pump_enable), .source_available(source_available),
                     .running(pump_running), .flow_present(flow_present));
    water_tank_model tank (.clk(clk), .reset(model_reset), .flow_present(flow_present),
                           .drain_enable(drain_enable), .level(tank_level));
    sensor_model sensors (.level(tank_level), .noise_mask(noise_mask),
                          .sensor_out(modeled_sensors));

    task automatic require_true(input logic condition, input string message);
        begin
            if (condition !== 1'b1)
                $fatal(1, "water_tank_system_tb cycle %0d: %s", cycle_count, message);
            check_count = check_count + 1;
        end
    endtask

    task automatic tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic clocks(input integer count);
        integer n;
        begin
            for (n = 0; n < count; n = n + 1)
                tick();
        end
    endtask

    task automatic require_reset_outputs;
        begin
            require_true(!pump_enable && !dry_run_detected && !protection_active,
                         "reset/disable must clear pump and protection");
            require_true(!timer_busy && !timer_done && sensor_valid == 2'b00 &&
                         sensor_debounced == 2'b00, "reset/disable must clear PULSE");
        end
    endtask

    // Release at a falling edge, so the next tick is the first capture a0.
    task automatic reset_controller(input logic reset_tank);
        begin
            @(negedge clk);
            reset = 1'b1;
            enable = 1'b1;
            fault_clear = 1'b0;
            model_reset = reset_tank;
            tick();
            require_reset_outputs();
            @(negedge clk);
            reset = 1'b0;
            model_reset = 1'b0;
        end
    endtask

    task automatic startup_low;
        integer n;
        begin
            for (n = 0; n < D + 2; n = n + 1) begin
                tick();
                require_true(sensor_valid == 2'b00 && !pump_enable,
                             "startup must wait for fresh fully qualified LOW");
            end
            tick();
            require_true(sensor_valid == 2'b11 && sensor_debounced == 2'b00 &&
                         !pump_enable, "LOW qualifies at a(2+D), before controller observation");
            tick();
            require_true(pump_enable && timer_busy && !timer_done,
                         "pump and protection window must start on the same edge");
            start_cycle = cycle_count;
        end
    endtask

    task automatic wait_qualified(input logic [1:0] value, input integer budget);
        integer n;
        begin
            n = 0;
            while (((sensor_valid !== 2'b11) || (sensor_debounced !== value)) && n < budget) begin
                tick();
                n = n + 1;
            end
            require_true(sensor_valid == 2'b11 && sensor_debounced == value,
                         "expected qualified threshold code did not arrive within budget");
        end
    endtask

    task automatic finish_normal_fill;
        integer n;
        integer observed_mid;
        begin
            n = 0;
            observed_mid = 0;
            while (pump_enable && n < 160) begin
                tick();
                require_true(!dry_run_detected && !protection_active,
                             "available source must complete filling without protection");
                if (sensor_debounced == 2'b01) begin
                    observed_mid = 1;
                    require_true(pump_enable, "MID must preserve an active pump command");
                end
                n = n + 1;
            end
            require_true(observed_mid && !pump_enable && sensor_debounced == 2'b11,
                         "normal fill must progress through MID and stop on FULL");
            require_true(tank_level >= 90 && tank_level <= 100 && !timer_busy,
                         "normal full tank must stay bounded and cancel its initial window");
        end
    endtask

    task automatic expect_timeout;
        begin
            while (cycle_count < start_cycle + WINDOW) begin
                tick();
                require_true(pump_enable && !dry_run_detected,
                             "timeout must not stop pump before controller observes done");
                if (cycle_count < start_cycle + WINDOW)
                    require_true(timer_busy && !timer_done, "protection timer expired early");
            end
            require_true(timer_done && !timer_busy && pump_enable,
                         "PULSE must complete exactly N cycles after pump start");
            tick();
            require_true(cycle_count == start_cycle + WINDOW + 1 && !pump_enable &&
                         dry_run_detected && protection_active && !timer_done,
                         "controller must latch protection exactly at N+1 cycles");
        end
    endtask

    // The raw transition first captures at e(N-D-2), so qualification and
    // timer completion both register at eN. No force or internal-state write.
    task automatic response_expiry_race(input logic [1:0] response);
        begin
            @(negedge clk);
            direct_sensors = 1'b1;
            directed_value = 2'b00;
            source_available = 1'b0;
            noise_mask = 2'b00;
            reset_controller(1'b1);
            startup_low();
            while (cycle_count < start_cycle + WINDOW - D - 3)
                tick();
            @(negedge clk);
            directed_value = response;
            while (cycle_count < start_cycle + WINDOW - 1)
                tick();
            require_true(sensor_debounced == 2'b00 && timer_busy && !timer_done,
                         "race fixture must retain old LOW until expiration edge");
            tick();
            require_true(sensor_debounced == response && timer_done && pump_enable &&
                         !dry_run_detected, "response and done must register together at eN");
            tick();
            require_true(!dry_run_detected && !protection_active && !timer_busy && !timer_done,
                         "simultaneously observed response must beat timeout");
            if (response == 2'b11)
                require_true(!pump_enable, "FULL must stop pump on the simultaneous observation");
            else
                require_true(pump_enable, "MID must preserve filling on the simultaneous observation");
        end
    endtask

    initial begin
        // A / E-startup: actual model feedback drives LOW -> MID -> FULL.
        $display("CASE A normal model filling; E startup reset");
        reset_controller(1'b1);
        startup_low();
        require_true(pump_running && flow_present, "source-available pump model must produce flow");
        finish_normal_fill();

        // B1: model-generated FULL is inverted to false LOW for two samples.
        $display("CASE B1 short false LOW on a full tank");
        clocks(4);
        @(negedge clk);
        noise_mask = 2'b11;
        clocks(D - 1);
        @(negedge clk);
        noise_mask = 2'b00;
        for (i = 0; i < D + 6; i = i + 1) begin
            tick();
            require_true(sensor_debounced == 2'b11 && !pump_enable && !dry_run_detected,
                         "short false LOW must neither qualify nor start pump");
        end

        // Model drainage gives FULL -> MID without restarting an idle pump.
        @(negedge clk);
        drain_enable = 1'b1;
        wait_qualified(2'b01, 100);
        clocks(3);
        require_true(!pump_enable && tank_level < 90 && tank_level >= 25,
                     "drained MID must retain IDLE hysteresis");
        @(negedge clk);
        drain_enable = 1'b0;

        // B2 / C: source absence and short false response while timing.
        $display("CASE B2 noise during monitoring; C exact dry-run timeout");
        source_available = 1'b0;
        reset_controller(1'b1);
        startup_low();
        require_true(pump_running && !flow_present, "absent source must suppress model flow");
        clocks(5);
        @(negedge clk);
        noise_mask = 2'b11;
        clocks(D - 1);
        @(negedge clk);
        noise_mask = 2'b00;
        for (i = 0; i < D + 6; i = i + 1) begin
            tick();
            require_true(sensor_debounced == 2'b00 && pump_enable && timer_busy,
                         "short false response must not qualify, stop, or cancel monitoring");
        end
        expect_timeout();
        require_true(tank_level == 0, "source absence must leave tank unfilled");

        // D: restored supply alone cannot retry; only explicit clear can.
        $display("CASE D latched protection and manual recovery");
        @(negedge clk);
        source_available = 1'b1;
        for (i = 0; i < WINDOW + 5; i = i + 1) begin
            tick();
            require_true(!pump_enable && dry_run_detected && protection_active && !flow_present,
                         "restored source must not cause automatic retry");
        end
        @(negedge clk);
        fault_clear = 1'b1;
        tick();
        require_true(!pump_enable && !dry_run_detected && !protection_active,
                     "fault clear must return to IDLE without same-edge restart");
        @(negedge clk);
        fault_clear = 1'b0;
        tick();
        require_true(pump_enable && timer_busy, "LOW must permit a fresh start after manual clear");
        finish_normal_fill();

        // E: reset active monitoring, then reset an already latched fault.
        $display("CASE E reset during monitoring and protection");
        @(negedge clk);
        direct_sensors = 1'b1;
        directed_value = 2'b00;
        source_available = 1'b0;
        reset_controller(1'b1);
        startup_low();
        clocks(8);
        reset_controller(1'b0);
        startup_low();
        expect_timeout();
        reset_controller(1'b0);
        startup_low();
        require_true(!dry_run_detected, "reset must release the protection latch");
        @(negedge clk);
        directed_value = 2'b01;
        wait_qualified(2'b01, D + 8);
        tick();
        require_true(pump_enable && !timer_busy,
                     "active-fill reset fixture must have accepted its MID response");
        reset_controller(1'b0);
        wait_qualified(2'b01, D + 8);
        tick();
        require_true(!pump_enable && !dry_run_detected,
                     "reset during FILLING must return to IDLE and not restart at MID");

        // F: both MID and FULL response cases meet done exactly.
        $display("CASE F MID and FULL response/expiry races");
        response_expiry_race(2'b11);
        response_expiry_race(2'b01);
        clocks(4);

        // G1: contradictory readings stop an established FILLING state.
        $display("CASE G contradictory thresholds and disable/re-enable");
        @(negedge clk);
        directed_value = 2'b10;
        wait_qualified(2'b10, D + 8);
        tick();
        require_true(!pump_enable && !dry_run_detected,
                     "contradictory readings in FILLING must stop without dry-run latch");
        reset_controller(1'b0);
        wait_qualified(2'b10, D + 8);
        clocks(3);
        require_true(!pump_enable && !timer_busy && !dry_run_detected,
                     "contradictory startup readings must inhibit a new start");

        // G2: an invalid code during WAIT_RESPONSE cancels its live timer.
        @(negedge clk);
        directed_value = 2'b00;
        wait_qualified(2'b00, D + 8);
        tick();
        require_true(pump_enable && timer_busy, "valid LOW must start after invalid-code inhibition");
        @(negedge clk);
        directed_value = 2'b10;
        wait_qualified(2'b10, D + 8);
        tick();
        require_true(!pump_enable && !timer_busy && !dry_run_detected,
                     "contradictory readings during monitoring must cancel and stop");

        // G3: disable erases validity, aborts operation, and restarts acquisition.
        @(negedge clk);
        directed_value = 2'b00;
        wait_qualified(2'b00, D + 8);
        tick();
        require_true(pump_enable && timer_busy, "disable fixture must have active monitoring");
        @(negedge clk);
        enable = 1'b0;
        tick();
        require_reset_outputs();
        clocks(2);
        require_reset_outputs();
        @(negedge clk);
        enable = 1'b1;
        startup_low();
        expect_timeout();
        @(negedge clk);
        enable = 1'b0;
        tick();
        require_reset_outputs();

        test_passed = 1;
        $display("PASS water_tank_system_tb (%0d checks, %0d cycles; cases A-G)",
                 check_count, cycle_count);
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "water_tank_system_tb watchdog expired");
    end
endmodule
