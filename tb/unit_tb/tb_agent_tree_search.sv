//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: tb_agent_tree_search.sv
// Description: Unit testbench for Speculative Tree Search & MCTS Scoring Engine.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module tb_agent_tree_search;

    logic                   clk;
    logic                   rst_n;
    logic                   eval_req_valid;
    logic [15:0]            temperature_threshold;
    logic [15:0]            branch_q_values [7:0];
    logic [15:0]            branch_visit_counts [7:0];
    logic [15:0]            total_visit_count;

    logic                   eval_resp_valid;
    logic [2:0]             best_branch_idx;
    logic [15:0]            best_branch_score;
    logic [7:0]             valid_branch_mask;

    int test_pass_count = 0;
    int test_fail_count = 0;

    // Device Under Test (DUT)
    agent_tree_search_engine dut (
        .clk(clk),
        .rst_n(rst_n),
        .eval_req_valid(eval_req_valid),
        .temperature_threshold(temperature_threshold),
        .branch_q_values(branch_q_values),
        .branch_visit_counts(branch_visit_counts),
        .total_visit_count(total_visit_count),
        .eval_resp_valid(eval_resp_valid),
        .best_branch_idx(best_branch_idx),
        .best_branch_score(best_branch_score),
        .valid_branch_mask(valid_branch_mask)
    );

    // 1.0 GHz Clock Generator
    always #0.5 clk = ~clk;

    initial begin
        $display("=========================================================");
        $display(" [TESTBENCH] START: tb_agent_tree_search (MCTS Engine)");
        $display("=========================================================");

        clk                   = 0;
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

        //-------------------------------------------------------------
        // Test 1: Standard MCTS UCT Selection with Known Q-values
        //-------------------------------------------------------------
        $display(" [INFO] Test 1: Evaluating 8 Candidate Branches with varied Q-values and Visits...");
        @(posedge clk);
        eval_req_valid        <= 1'b1;
        temperature_threshold <= 16'd100; // Filter branches below 100
        total_visit_count     <= 16'd1024; // sqrt(1024) = 32

        // Branch 0: Q=50, visits=10  (Pruned: Q < 100)
        // Branch 1: Q=200, visits=5  (Keep)
        // Branch 2: Q=300, visits=2  (Keep, Expected Best)
        // Branch 3: Q=80, visits=1   (Pruned: Q < 100)
        // Branch 4: Q=150, visits=4  (Keep)
        // Branch 5: Q=120, visits=8  (Keep)
        // Branch 6: Q=250, visits=15 (Keep)
        // Branch 7: Q=180, visits=20 (Keep)

        branch_q_values[0] <= 16'd50;  branch_visit_counts[0] <= 16'd10;
        branch_q_values[1] <= 16'd200; branch_visit_counts[1] <= 16'd5;
        branch_q_values[2] <= 16'd300; branch_visit_counts[2] <= 16'd2;
        branch_q_values[3] <= 16'd80;  branch_visit_counts[3] <= 16'd1;
        branch_q_values[4] <= 16'd150; branch_visit_counts[4] <= 16'd4;
        branch_q_values[5] <= 16'd120; branch_visit_counts[5] <= 16'd8;
        branch_q_values[6] <= 16'd250; branch_visit_counts[6] <= 16'd15;
        branch_q_values[7] <= 16'd180; branch_visit_counts[7] <= 16'd20;

        @(posedge clk);
        eval_req_valid <= 1'b0;

        // Wait for response valid from pipeline
        while (!eval_resp_valid) @(posedge clk);
        #0.1;

        if (eval_resp_valid && best_branch_idx == 3'd2) begin
            $display(" [PASS] Test 1: Best branch correctly selected (Idx: %0d, Score: %0d)", best_branch_idx, best_branch_score);
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 1: Expected best branch index 2, got %0d (eval_resp_valid=%0b)", best_branch_idx, eval_resp_valid);
            test_fail_count++;
        end

        // Check pruning mask: bits 0 and 3 should be 0 (below threshold 100), others 1 -> 8'b1111_0110 = 0xF6
        if (valid_branch_mask == 8'hF6) begin
            $display(" [PASS] Test 2: Temperature Pruning Mask validated (Mask: 0x%h)", valid_branch_mask);
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 2: Expected prune mask 0xF6, got 0x%h", valid_branch_mask);
            test_fail_count++;
        end

        //-------------------------------------------------------------
        // Test 3: Unvisited Branch Exploration Bonus
        //-------------------------------------------------------------
        $display(" [INFO] Test 3: Testing Unvisited Node Exploration Priority...");
        @(posedge clk);
        eval_req_valid        <= 1'b1;
        temperature_threshold <= 16'd0;
        total_visit_count     <= 16'd256;

        for (int i = 0; i < 8; i++) begin
            branch_q_values[i]     <= 16'd100;
            branch_visit_counts[i] <= 16'd50;
        end
        // Branch 5 has 0 visits -> gets large exploration bonus 512
        branch_visit_counts[5] <= 16'd0;

        @(posedge clk);
        eval_req_valid <= 1'b0;

        // Wait for response valid
        while (!eval_resp_valid) @(posedge clk);
        #0.1;

        if (eval_resp_valid && best_branch_idx == 3'd5 && best_branch_score == 16'd612) begin
            $display(" [PASS] Test 3: Unvisited branch exploration bonus verified (Idx: %0d, Score: %0d)", best_branch_idx, best_branch_score);
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 3: Unvisited branch selection failed (got idx: %0d, score: %0d, valid=%0b)", best_branch_idx, best_branch_score, eval_resp_valid);
            test_fail_count++;
        end

        $display("=========================================================");
        $display(" [TESTBENCH SUMMARY] tb_agent_tree_search: %0d PASSED, %0d FAILED", test_pass_count, test_fail_count);
        $display("=========================================================");

        if (test_fail_count == 0)
            $display(" RESULT: PASS");
        else
            $display(" RESULT: FAIL");

        $finish;
    end

endmodule
