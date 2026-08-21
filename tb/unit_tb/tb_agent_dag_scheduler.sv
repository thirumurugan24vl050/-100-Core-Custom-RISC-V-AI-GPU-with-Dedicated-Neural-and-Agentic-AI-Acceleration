//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: tb_agent_dag_scheduler.sv
// Description: Self-Checking Testbench for Hardware Agent Task DAG Scheduler.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module tb_agent_dag_scheduler;
    import riscv_ai_gpu_pkg::*;

    logic clk;
    logic rst_n;

    logic                   insert_task_valid;
    logic [DAG_NODE_ID_WIDTH-1:0] insert_node_id;
    logic [2:0]             insert_priority;
    logic [MAX_DAG_NODES-1:0] insert_dep_mask;
    logic [7:0]             insert_cluster_target;
    logic [31:0]            insert_pc_start;
    logic [31:0]            insert_context_ptr;
    logic                   insert_task_ready;

    logic                   task_complete_valid;
    logic [DAG_NODE_ID_WIDTH-1:0] task_complete_id;

    logic                   dispatch_valid;
    logic [DAG_NODE_ID_WIDTH-1:0] dispatch_node_id;
    logic [7:0]             dispatch_cluster_target;
    logic [31:0]            dispatch_pc_start;
    logic [31:0]            dispatch_context_ptr;
    logic                   dispatch_ready;

    logic [6:0]             active_task_count;
    logic [MAX_DAG_NODES-1:0] completed_task_mask;

    int test_pass_count = 0;
    int test_fail_count = 0;

    // Clock
    initial begin
        clk = 0;
        forever #0.5 clk = ~clk;
    end

    // Instantiate DUT
    agent_dag_scheduler dut (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .insert_task_valid      (insert_task_valid),
        .insert_node_id         (insert_node_id),
        .insert_priority        (insert_priority),
        .insert_dep_mask        (insert_dep_mask),
        .insert_cluster_target  (insert_cluster_target),
        .insert_pc_start        (insert_pc_start),
        .insert_context_ptr     (insert_context_ptr),
        .insert_task_ready      (insert_task_ready),
        .task_complete_valid    (task_complete_valid),
        .task_complete_id       (task_complete_id),
        .dispatch_valid         (dispatch_valid),
        .dispatch_node_id       (dispatch_node_id),
        .dispatch_cluster_target(dispatch_cluster_target),
        .dispatch_pc_start      (dispatch_pc_start),
        .dispatch_context_ptr   (dispatch_context_ptr),
        .dispatch_ready         (dispatch_ready),
        .active_task_count      (active_task_count),
        .completed_task_mask    (completed_task_mask)
    );

    initial begin
        $display("=========================================================");
        $display(" [TESTBENCH] START: tb_agent_dag_scheduler");
        $display("=========================================================");

        rst_n               = 0;
        insert_task_valid   = 0;
        task_complete_valid = 0;
        dispatch_ready      = 1;

        #2 rst_n = 1;
        #2;

        // 1. Insert Task 0: Root node (priority 3, no dependencies)
        $display(" [INFO] Inserting Task 0 (Prio 3, No Deps)...");
        insert_task_valid     = 1;
        insert_node_id        = 6'd0;
        insert_priority       = 3'd3;
        insert_dep_mask       = 64'd0;
        insert_cluster_target = 8'd0;
        insert_pc_start       = 32'h00001000;
        insert_context_ptr    = 32'h00002000;
        #1;

        // 2. Insert Task 1: Root node (priority 5, no dependencies)
        $display(" [INFO] Inserting Task 1 (Prio 5, No Deps)...");
        insert_node_id        = 6'd1;
        insert_priority       = 3'd5;
        insert_dep_mask       = 64'd0;
        insert_cluster_target = 8'd1;
        insert_pc_start       = 32'h00001100;
        insert_context_ptr    = 32'h00002100;
        #1;

        // 3. Insert Task 2: Dependent on Task 0 (bit 0) and Task 1 (bit 1), Priority 7
        $display(" [INFO] Inserting Task 2 (Prio 7, Dependent on Task 0 & 1)...");
        insert_node_id        = 6'd2;
        insert_priority       = 3'd7;
        insert_dep_mask       = 64'h0000000000000003; // Mask: bits 0 & 1
        insert_cluster_target = 8'd2;
        insert_pc_start       = 32'h00001200;
        insert_context_ptr    = 32'h00002200;
        #1;
        insert_task_valid     = 0;
        #2;

        // 4. Verify that Task 1 (Prio 5) is dispatched first over Task 0 (Prio 3)
        if (dispatch_valid && dispatch_node_id == 6'd1) begin
            $display(" [PASS] Test 1: Task 1 dispatched first due to higher priority (Prio 5 > Prio 3)");
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 1: Expected Task 1 dispatch, got Task %0d", dispatch_node_id);
            test_fail_count++;
        end
        #1;

        // 5. Verify that Task 0 is dispatched next
        if (dispatch_valid && dispatch_node_id == 6'd0) begin
            $display(" [PASS] Test 2: Task 0 dispatched next");
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 2: Expected Task 0 dispatch, got Task %0d", dispatch_node_id);
            test_fail_count++;
        end
        #1;

        // 6. Verify Task 2 is NOT dispatched yet because Task 0 & 1 are not completed
        if (!dispatch_valid) begin
            $display(" [PASS] Test 3: Task 2 correctly blocked on prerequisites (Task 0 and Task 1)");
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 3: Task 2 illegally dispatched before dependency resolution");
            test_fail_count++;
        end

        // 7. Complete Task 0 and Task 1
        $display(" [INFO] Sending Task 1 completion...");
        task_complete_valid = 1;
        task_complete_id    = 6'd1;
        #1;
        $display(" [INFO] Sending Task 0 completion...");
        task_complete_id    = 6'd0;
        #1;
        task_complete_valid = 0;
        #2;

        // 8. Verify Task 2 is now dispatched
        if (dispatch_valid && dispatch_node_id == 6'd2) begin
            $display(" [PASS] Test 4: Task 2 unblocked and dispatched immediately upon dependency satisfaction");
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 4: Task 2 failed to fire after dependencies resolved");
            test_fail_count++;
        end

        $display("=========================================================");
        $display(" [TESTBENCH SUMMARY] tb_agent_dag_scheduler: %0d PASSED, %0d FAILED", test_pass_count, test_fail_count);
        $display("=========================================================");

        if (test_fail_count == 0)
            $display(" RESULT: PASS");
        else
            $display(" RESULT: FAIL");

        $finish;
    end

endmodule
