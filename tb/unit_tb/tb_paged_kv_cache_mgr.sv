//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: tb_paged_kv_cache_mgr.sv
// Description: Self-Checking Testbench for Paged KV-Cache Memory Manager.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module tb_paged_kv_cache_mgr;
    import riscv_ai_gpu_pkg::*;

    logic clk;
    logic rst_n;

    logic                   kv_req_valid;
    logic [1:0]             kv_req_op;
    logic [5:0]             kv_context_id;
    logic [9:0]             kv_virtual_page;
    logic                   kv_resp_valid;
    logic [KV_PAGE_ID_WIDTH-1:0] kv_resp_physical_page;
    logic                   kv_resp_hit;
    logic                   kv_resp_error;
    logic [10:0]            free_page_count;
    logic [10:0]            allocated_page_count;

    int test_pass_count = 0;
    int test_fail_count = 0;

    // Clock
    initial begin
        clk = 0;
        forever #0.5 clk = ~clk;
    end

    // Instantiate DUT
    paged_kv_cache_mgr dut (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .kv_req_valid          (kv_req_valid),
        .kv_req_op             (kv_req_op),
        .kv_context_id         (kv_context_id),
        .kv_virtual_page       (kv_virtual_page),
        .kv_resp_valid         (kv_resp_valid),
        .kv_resp_physical_page (kv_resp_physical_page),
        .kv_resp_hit           (kv_resp_hit),
        .kv_resp_error         (kv_resp_error),
        .free_page_count       (free_page_count),
        .allocated_page_count  (allocated_page_count)
    );

    initial begin
        $display("=========================================================");
        $display(" [TESTBENCH] START: tb_paged_kv_cache_mgr");
        $display("=========================================================");

        rst_n           = 0;
        kv_req_valid    = 0;
        kv_req_op       = 2'b00;
        kv_context_id   = 6'd0;
        kv_virtual_page = 10'd0;

        #2 rst_n = 1;
        #2;

        // 1. Initial State Check (1024 free pages)
        if (free_page_count == 11'd1024) begin
            $display(" [PASS] Test 1: Initial Free Page Count = 1024");
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 1: Initial Free Page Count = %0d", free_page_count);
            test_fail_count++;
        end

        // 2. Allocate Page for Context 0, Virtual Page 0
        $display(" [INFO] Allocating KV page for Context 0, Virtual Page 0...");
        kv_req_valid    = 1;
        kv_req_op       = 2'b01; // Alloc
        kv_context_id   = 6'd0;
        kv_virtual_page = 10'd0;
        #1;
        kv_req_valid    = 0;
        #1;

        if (kv_resp_hit && kv_resp_physical_page == 10'd0) begin
            $display(" [PASS] Test 2: Allocated Physical Page 0 for (Context 0, VPage 0)");
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 2: Allocation failed");
            test_fail_count++;
        end

        // 3. Lookup Allocated Page
        $display(" [INFO] Looking up (Context 0, VPage 0)...");
        kv_req_valid    = 1;
        kv_req_op       = 2'b00; // Lookup
        #1;
        kv_req_valid    = 0;
        #1;

        if (kv_resp_hit && kv_resp_physical_page == 10'd0) begin
            $display(" [PASS] Test 3: Page Table Lookup Hit (PPage = 0)");
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 3: Lookup missed");
            test_fail_count++;
        end

        // 4. Free Allocated Page
        $display(" [INFO] Freeing KV page...");
        kv_req_valid = 1;
        kv_req_op    = 2'b10; // Free
        #1;
        kv_req_valid = 0;
        #1;

        if (free_page_count == 11'd1024) begin
            $display(" [PASS] Test 4: Page freed and returned to free pool (Free count = 1024)");
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 4: Free failed (Free count = %0d)", free_page_count);
            test_fail_count++;
        end

        $display("=========================================================");
        $display(" [TESTBENCH SUMMARY] tb_paged_kv_cache_mgr: %0d PASSED, %0d FAILED", test_pass_count, test_fail_count);
        $display("=========================================================");

        if (test_fail_count == 0)
            $display(" RESULT: PASS");
        else
            $display(" RESULT: FAIL");

        $finish;
    end

endmodule
