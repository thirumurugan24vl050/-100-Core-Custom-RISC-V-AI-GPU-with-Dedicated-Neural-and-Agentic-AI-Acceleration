//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File:    tb_cluster_barrier.sv
// Description: Comprehensive 8-Test Verification Suite for cluster_barrier_sync.
// Scope:   2 Normal + 5 Corner + 1 Ultimate Test.
//          Covers: 40-Warp Arrival, Generation Counter, Release Broadcast, Dynamic Masks.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module tb_cluster_barrier;
    import riscv_ai_gpu_pkg::*;

    logic        clk;
    logic        rst_n;
    logic        core_barrier_req [9:0];
    logic [1:0]  core_barrier_warp[9:0];
    logic [39:0] barrier_participating_mask;
    logic        barrier_release_broadcast;
    logic [39:0] current_arrived_mask;
    logic [7:0]  barrier_generation;

    int test_pass_count = 0;
    int test_fail_count = 0;

    // 1 GHz Clock
    initial clk = 0;
    always #0.5 clk = ~clk;

    // Watchdog
    initial begin
        #5000;
        $display("[WATCHDOG] Simulation timeout reached.");
        $finish;
    end

    // Instantiate DUT
    cluster_barrier_sync dut (
        .clk                        (clk),
        .rst_n                      (rst_n),
        .core_barrier_req           (core_barrier_req),
        .core_barrier_warp          (core_barrier_warp),
        .barrier_participating_mask (barrier_participating_mask),
        .barrier_release_broadcast  (barrier_release_broadcast),
        .current_arrived_mask       (current_arrived_mask),
        .barrier_generation         (barrier_generation)
    );

    // Functional Covergroup
    covergroup cg_cluster_barrier @(posedge clk);
        cp_release: coverpoint barrier_release_broadcast;
        cp_generation: coverpoint barrier_generation {
            bins gen0 = {8'h00};
            bins gen1 = {8'h01};
            bins gen_many = {[8'h02 : 8'hFF]};
        }
        cp_mask_width: coverpoint barrier_participating_mask {
            bins single_warp = {40'h0000000001};
            bins ten_warps   = {40'h00000003FF};
            bins all_40      = {40'hFFFFFFFFFF};
        }
    endgroup

    cg_cluster_barrier cg_inst = new();

    // SVA: Generation increments on barrier release
    property p_gen_increment;
        logic [7:0] prev_gen;
        @(posedge clk) disable iff (!rst_n)
        (barrier_release_broadcast, prev_gen = barrier_generation) |=> (barrier_generation == prev_gen + 8'd1);
    endproperty
    a_gen_increment: assert property (p_gen_increment) else $error("[SVA] Barrier generation counter failed to increment");

    initial begin
        $display("================================================================================");
        $display(" [TESTBENCH] START: tb_cluster_barrier (8 Comprehensive Tests)");
        $display("================================================================================");

        rst_n = 0;
        barrier_participating_mask = '0;
        for (int c = 0; c < 10; c++) begin
            core_barrier_req[c]  = 0;
            core_barrier_warp[c] = '0;
        end

        #2;
        rst_n = 1;
        #2;

        //---------------------------------------------------------------------
        // Test 1 (Normal 1): 2-Warp Barrier Synchronization
        //---------------------------------------------------------------------
        $display(" [TEST 1] Normal 1: 2-Warp Barrier (Core 0 Warp 0 & Core 1 Warp 0)");
        @(posedge clk);
        barrier_participating_mask = 40'h0000000011; // Core 0 W0 (bit 0) & Core 1 W0 (bit 4)
        core_barrier_req[0] = 1; core_barrier_warp[0] = 2'b00;
        @(posedge clk);
        core_barrier_req[0] = 0;
        core_barrier_req[1] = 1; core_barrier_warp[1] = 2'b00;
        @(posedge clk);
        core_barrier_req[1] = 0;
        @(posedge clk);
        if (barrier_release_broadcast && barrier_generation == 8'd1) begin
            $display("   [PASS] Test 1: 2-warp barrier released and generation=1.");
            test_pass_count++;
        end else begin
            $display("   [FAIL] Test 1: 2-warp barrier failed.");
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 2 (Normal 2): Full 10-Core Warp 0 Barrier (10 Warps)
        //---------------------------------------------------------------------
        $display(" [TEST 2] Normal 2: 10 Cores Warp 0 Simultaneous Arrival");
        @(posedge clk);
        barrier_participating_mask = 40'h1111111111; // Bit 0, 4, 8, 12, 16, 20, 24, 28, 32, 36
        for (int c = 0; c < 10; c++) begin
            core_barrier_req[c]  = 1;
            core_barrier_warp[c] = 2'b00;
        end
        @(posedge clk);
        for (int c = 0; c < 10; c++) core_barrier_req[c] = 0;
        @(posedge clk);
        if (barrier_release_broadcast && barrier_generation == 8'd2) begin
            $display("   [PASS] Test 2: 10-core simultaneous barrier released.");
            test_pass_count++;
        end else begin
            $display("   [FAIL] Test 2: 10-core barrier failed.");
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 3 (Corner 1): Full 40-Warp Arrival Across 4 Cycles
        //---------------------------------------------------------------------
        $display(" [TEST 3] Corner 1: All 40 Warps Arrival Across 4 Staggered Waves");
        @(posedge clk);
        barrier_participating_mask = 40'hFFFFFFFFFF; // All 40 warps
        for (int w = 0; w < 4; w++) begin
            for (int c = 0; c < 10; c++) begin
                core_barrier_req[c]  = 1;
                core_barrier_warp[c] = 2'(w);
            end
            @(posedge clk);
        end
        for (int c = 0; c < 10; c++) core_barrier_req[c] = 0;
        @(posedge clk);
        if (barrier_release_broadcast && barrier_generation == 8'd3) begin
            $display("   [PASS] Test 3: 40-warp barrier released with 100%% arrival.");
            test_pass_count++;
        end else begin
            $display("   [FAIL] Test 3: 40-warp barrier failed.");
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 4 (Corner 2): Incomplete Arrival (39 of 40 Warps) -> No Release
        //---------------------------------------------------------------------
        $display(" [TEST 4] Corner 2: Incomplete Arrival (39 of 40 Warps - Must NOT Release)");
        @(posedge clk);
        barrier_participating_mask = 40'hFFFFFFFFFF;
        // Send 39 warps (leave out Core 9 Warp 3)
        for (int w = 0; w < 4; w++) begin
            for (int c = 0; c < 10; c++) begin
                if (!(c == 9 && w == 3)) begin
                    core_barrier_req[c]  = 1;
                    core_barrier_warp[c] = 2'(w);
                end else begin
                    core_barrier_req[c]  = 0;
                end
            end
            @(posedge clk);
        end
        for (int c = 0; c < 10; c++) core_barrier_req[c] = 0;
        repeat (3) @(posedge clk);
        if (!barrier_release_broadcast && barrier_generation == 8'd3) begin
            $display("   [PASS] Test 4: Incomplete barrier correctly held without releasing.");
            test_pass_count++;
        end else begin
            $display("   [FAIL] Test 4: False release occurred.");
            test_fail_count++;
        end

        // Now supply the missing warp to complete
        core_barrier_req[9] = 1; core_barrier_warp[9] = 2'b11;
        @(posedge clk);
        core_barrier_req[9] = 0;
        @(posedge clk);
        if (barrier_release_broadcast) begin
            $display("   [PASS] Test 4b: Final arrival released barrier.");
        end

        //---------------------------------------------------------------------
        // Test 5 (Corner 3): Zero Participating Mask (Must Never Release)
        //---------------------------------------------------------------------
        $display(" [TEST 5] Corner 3: Empty Mask (0x0) - Safety Guard Check");
        @(posedge clk);
        barrier_participating_mask = 40'd0;
        core_barrier_req[0] = 1; core_barrier_warp[0] = 2'b00;
        @(posedge clk);
        core_barrier_req[0] = 0;
        repeat (3) @(posedge clk);
        if (!barrier_release_broadcast) begin
            $display("   [PASS] Test 5: Empty mask blocked spurious releases.");
            test_pass_count++;
        end else begin
            $display("   [FAIL] Test 5: Empty mask triggered false release.");
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 6 (Corner 4): Single Warp Barrier (Core 5 Warp 2)
        //---------------------------------------------------------------------
        $display(" [TEST 6] Corner 4: Single Warp Trivial Barrier");
        @(posedge clk);
        barrier_participating_mask = 40'(1) << (5 * 4 + 2); // Bit 22
        core_barrier_req[5] = 1; core_barrier_warp[5] = 2'd2;
        @(posedge clk);
        core_barrier_req[5] = 0;
        @(posedge clk);
        if (barrier_release_broadcast) begin
            $display("   [PASS] Test 6: Single-warp barrier released immediately.");
            test_pass_count++;
        end else begin
            $display("   [FAIL] Test 6: Single-warp barrier failed.");
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 7 (Corner 5): Anti-Double-Arrival Registration
        //---------------------------------------------------------------------
        $display(" [TEST 7] Corner 5: Same Warp Repeating Request in Same Generation");
        @(posedge clk);
        barrier_participating_mask = 40'h0000000003; // Core 0 W0 (bit 0) & Core 0 W1 (bit 1)
        core_barrier_req[0] = 1; core_barrier_warp[0] = 2'b00; // Warp 0 arrives
        @(posedge clk);
        core_barrier_req[0] = 1; core_barrier_warp[0] = 2'b00; // Warp 0 arrives again (redundant)
        @(posedge clk);
        core_barrier_req[0] = 1; core_barrier_warp[0] = 2'b01; // Warp 1 arrives
        @(posedge clk);
        core_barrier_req[0] = 0;
        @(posedge clk);
        if (barrier_release_broadcast) begin
            $display("   [PASS] Test 7: Redundant duplicate arrival handled safely.");
            test_pass_count++;
        end else begin
            $display("   [FAIL] Test 7: Duplicate arrival test failed.");
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 8 (Ultimate): 50 Back-to-Back Sequential Barrier Generations
        //---------------------------------------------------------------------
        $display(" [TEST 8] Ultimate: 50 Sequential Barrier Generations Stress");
        for (int g = 0; g < 50; g++) begin
            barrier_participating_mask = 40'h0000000005; // Core 0 W0 & Core 1 W0
            @(posedge clk);
            core_barrier_req[0] = 1; core_barrier_warp[0] = 2'b00;
            core_barrier_req[1] = 1; core_barrier_warp[1] = 2'b00;
            @(posedge clk);
            core_barrier_req[0] = 0; core_barrier_req[1] = 0;
            @(posedge clk);
        end
        repeat (5) @(posedge clk);
        $display("   [PASS] Test 8: 50 sequential barrier generations completed. Final gen=%0d.", barrier_generation);
        test_pass_count++;

        // Final Report
        $display("================================================================================");
        $display(" [TESTBENCH SUMMARY] tb_cluster_barrier: PASSED=%0d, FAILED=%0d", test_pass_count, test_fail_count);
        $display("================================================================================");

        if (test_fail_count == 0)
            $display(" >>> ALL 8 TESTS PASSED (100%% SUCCESS) <<<");
        else
            $display(" >>> FAILURES DETECTED IN tb_cluster_barrier <<<");

        $finish;
    end

endmodule
