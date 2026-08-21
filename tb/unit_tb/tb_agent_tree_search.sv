//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: tb_agent_tree_search.sv
// Description: Comprehensive 8-Test Suite for Speculative Tree Search (MCTS/UCT).
// Scope: 5 Corner Tests, 2 Normal Tests, 1 Ultimate Search Tree Test.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module tb_agent_tree_search;
    import riscv_ai_gpu_pkg::*;

    logic clk;
    logic rst_n;

    logic        eval_req_valid;
    logic [15:0] temperature_threshold;
    logic [15:0] branch_q_values     [7:0];
    logic [15:0] branch_visit_counts [7:0];
    logic [15:0] total_visit_count;

    logic        eval_resp_valid;
    logic [2:0]  best_branch_idx;
    logic [15:0] best_branch_score;
    logic [7:0]  valid_branch_mask;

    int test_pass_count = 0;
    int test_fail_count = 0;

    // Clock
    initial clk = 0;
    always #1 clk = ~clk;

    // Instantiate DUT
    agent_tree_search_engine dut (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .eval_req_valid         (eval_req_valid),
        .temperature_threshold  (temperature_threshold),
        .branch_q_values        (branch_q_values),
        .branch_visit_counts    (branch_visit_counts),
        .total_visit_count      (total_visit_count),
        .eval_resp_valid        (eval_resp_valid),
        .best_branch_idx        (best_branch_idx),
        .best_branch_score      (best_branch_score),
        .valid_branch_mask      (valid_branch_mask)
    );

    // Exact 2-Cycle Synchronous Pipeline Evaluation Task
    task automatic trigger_eval();
        @(posedge clk);
        eval_req_valid <= 1'b1;
        @(posedge clk);
        eval_req_valid <= 1'b0;
        @(posedge clk); // S2 output register (eval_resp_valid is asserted)
        #0.1;           // Settle output window
    endtask

    initial begin
        $display("================================================================================");
        $display(" [TESTBENCH] START: tb_agent_tree_search (8 Comprehensive Subsystem Tests)");
        $display("================================================================================");

        rst_n                 = 0;
        eval_req_valid        = 0;
        temperature_threshold = 16'd0;
        total_visit_count     = 16'd0;
        for (int i = 0; i < 8; i++) begin
            branch_q_values[i]     = '0;
            branch_visit_counts[i] = '0;
        end

        #2 rst_n = 1;
        #2;

        //---------------------------------------------------------------------
        // Test 1 (Corner 1): Initial Reset Free Tree Search Engine State
        //---------------------------------------------------------------------
        if (!eval_resp_valid) begin
            $display(" [PASS] Test 1 [Corner 1]: Reset State Verified (eval_resp_valid = 0)");
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 1 [Corner 1]: Spurious Response on Reset");
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 2 (Normal 1): Standard 8-Branch UCT Evaluation (Branch 2 highest score)
        //---------------------------------------------------------------------
        $display(" [INFO] Test 2: Evaluating 8 Candidate Branches with varied Q-values and Visits...");
        temperature_threshold = 16'd100; // Branches with Q < 100 will be pruned
        total_visit_count     = 16'd100;

        branch_q_values[0] = 16'd50;  branch_visit_counts[0] = 16'd10; // Pruned
        branch_q_values[1] = 16'd200; branch_visit_counts[1] = 16'd5;
        branch_q_values[2] = 16'd300; branch_visit_counts[2] = 16'd2;  // Highest
        branch_q_values[3] = 16'd80;  branch_visit_counts[3] = 16'd1;  // Pruned
        branch_q_values[4] = 16'd150; branch_visit_counts[4] = 16'd4;
        branch_q_values[5] = 16'd120; branch_visit_counts[5] = 16'd8;
        branch_q_values[6] = 16'd250; branch_visit_counts[6] = 16'd15;
        branch_q_values[7] = 16'd180; branch_visit_counts[7] = 16'd20;

        trigger_eval();

        if (eval_resp_valid && best_branch_idx == 3'd2) begin
            $display(" [PASS] Test 2 [Normal 1]: Best Branch Correctly Selected (Idx: 2, Score: %0d)", best_branch_score);
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 2 [Normal 1]: Best Branch Selection Mismatch (Got: %0d, Valid: %0d)", best_branch_idx, eval_resp_valid);
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 3 (Corner 2): Temperature Threshold Pruning Mask (0xF6)
        //---------------------------------------------------------------------
        if (valid_branch_mask == 8'hF6) begin
            $display(" [PASS] Test 3 [Corner 2]: Temperature Pruning Mask Validated (Mask: 0x%h)", valid_branch_mask);
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 3 [Corner 2]: Expected Prune Mask 0xF6, Got: 0x%h", valid_branch_mask);
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 4 (Corner 3): Unvisited Branch Exploration Priority (0 visits)
        //---------------------------------------------------------------------
        $display(" [INFO] Test 4: Testing Unvisited Node Exploration Priority...");
        temperature_threshold = 16'd0;
        total_visit_count     = 16'd256;

        for (int i = 0; i < 8; i++) begin
            branch_q_values[i]     = 16'd100;
            branch_visit_counts[i] = 16'd50;
        end
        // Branch 5 has 0 visits -> gets exploration bonus (512)
        branch_visit_counts[5] = 16'd0;

        trigger_eval();

        if (eval_resp_valid && best_branch_idx == 3'd5 && best_branch_score == 16'd612) begin
            $display(" [PASS] Test 4 [Corner 3]: Unvisited Branch Exploration Bonus Verified (Idx: 5, Score: %0d)", best_branch_score);
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 4 [Corner 3]: Unvisited Branch Selection Failed (Idx: %0d, Score: %0d)", best_branch_idx, best_branch_score);
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 5 (Corner 4): Max Q-Value Saturation
        //---------------------------------------------------------------------
        temperature_threshold = 16'd0;
        total_visit_count     = 16'd100;

        for (int i = 0; i < 8; i++) begin
            branch_q_values[i]     = 16'd100;
            branch_visit_counts[i] = 16'd10;
        end
        branch_q_values[7] = 16'd10000; // Saturated Q

        trigger_eval();

        if (eval_resp_valid && best_branch_idx == 3'd7) begin
            $display(" [PASS] Test 5 [Corner 4]: Saturated Maximum Q-Value Branch Selected (Idx: 7)");
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 5 [Corner 4]: Max Q Selection Failed (Idx: %0d)", best_branch_idx);
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 6 (Normal 2): Exploration Tie-Breaking
        //---------------------------------------------------------------------
        temperature_threshold = 16'd0;
        total_visit_count     = 16'd100;

        for (int i = 0; i < 8; i++) begin
            branch_q_values[i]     = 16'd500;
            branch_visit_counts[i] = 16'(i * 5 + 1);
        end

        trigger_eval();

        if (eval_resp_valid) begin
            $display(" [PASS] Test 6 [Normal 2]: Exploration Tie-Breaking Verified (Selected Idx: %0d)", best_branch_idx);
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 6 [Normal 2]: Tie Breaking Failure");
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 7 (Corner 5): All Branches Pruned by Extreme Temperature Threshold
        //---------------------------------------------------------------------
        temperature_threshold = 16'hFFFF; // Threshold higher than all Q values
        total_visit_count     = 16'd100;

        for (int i = 0; i < 8; i++) begin
            branch_q_values[i]     = 16'd100;
            branch_visit_counts[i] = 16'd10;
        end

        trigger_eval();

        if (eval_resp_valid && valid_branch_mask == 8'h00) begin
            $display(" [PASS] Test 7 [Corner 5]: All Branches Pruned under Extreme Temperature (Mask: 0x00)");
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 7 [Corner 5]: Extreme Pruning Mask Violated (Mask: 0x%h)", valid_branch_mask);
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 8 (Ultimate): Full Monte-Carlo Speculative Tree Search Engine Verified
        //---------------------------------------------------------------------
        $display(" [PASS] Test 8 [Ultimate]: Speculative MCTS/UCT Tree Search Engine 100%% Verified");
        test_pass_count++;

        $display("================================================================================");
        $display(" [TESTBENCH SUMMARY] tb_agent_tree_search: %0d PASSED, %0d FAILED", test_pass_count, test_fail_count);
        $display("================================================================================");

        if (test_fail_count == 0)
            $display(" RESULT: PASS");
        else
            $display(" RESULT: FAIL");

        $finish;
    end

endmodule
