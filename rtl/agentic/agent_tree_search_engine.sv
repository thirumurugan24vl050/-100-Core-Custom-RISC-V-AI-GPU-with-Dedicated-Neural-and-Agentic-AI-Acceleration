//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: agent_tree_search_engine.sv
// Description: Speculative Tree-Search & MCTS Rollout Scoring Accelerator.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module agent_tree_search_engine import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Evaluation Request
    input  logic                   eval_req_valid,
    input  logic [15:0]            temperature_threshold, // Q8.8 threshold
    input  logic [15:0]            branch_q_values [7:0], // 8 Candidate branches Q-scores (Q8.8)
    input  logic [15:0]            branch_visit_counts [7:0], // Visit counts n_i
    input  logic [15:0]            total_visit_count,     // Total parent visits N

    // Evaluation Output
    output logic                   eval_resp_valid,
    output logic [2:0]             best_branch_idx,
    output logic [15:0]            best_branch_score,
    output logic [7:0]             valid_branch_mask // Pruning mask (1 = Keep, 0 = Prune)
);

    // Stage 1: UCT Score Calculation
    // Score_i = Q_i + Exploration_Term
    logic                   s1_valid;
    logic [15:0]            s1_uct_scores [7:0];
    logic [7:0]             s1_prune_mask;

    // Fast integer sqrt approximation for exploration term
    function automatic logic [7:0] fast_sqrt16(input logic [15:0] val);
        logic [15:0] r;
        begin
            // Piecewise or shift approximation
            if (val >= 16'd4096) fast_sqrt16 = 8'd64;
            else if (val >= 16'd1024) fast_sqrt16 = 8'd32;
            else if (val >= 16'd256)  fast_sqrt16 = 8'd16;
            else if (val >= 16'd64)   fast_sqrt16 = 8'd8;
            else fast_sqrt16 = 8'd4;
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid      <= 1'b0;
            s1_prune_mask <= '0;
            for (int i = 0; i < 8; i++) s1_uct_scores[i] <= '0;
        end else begin
            s1_valid <= eval_req_valid;
            if (eval_req_valid) begin
                logic [7:0] total_sqrt;
                total_sqrt = fast_sqrt16(total_visit_count);

                for (int i = 0; i < 8; i++) begin
                    logic [15:0] explore_bonus;
                    if (branch_visit_counts[i] == 0)
                        explore_bonus = 16'd512; // High exploration for unvisited node
                    else
                        explore_bonus = {8'd0, (total_sqrt / (branch_visit_counts[i][7:0] + 8'd1))};

                    s1_uct_scores[i] <= branch_q_values[i] + explore_bonus;

                    // Prune branches falling below temperature cutoff
                    s1_prune_mask[i] <= (branch_q_values[i] >= temperature_threshold);
                end
            end
        end
    end

    // Stage 2: Best Branch Selection (ArgMax)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            eval_resp_valid   <= 1'b0;
            best_branch_idx   <= '0;
            best_branch_score <= '0;
            valid_branch_mask <= '0;
        end else begin
            eval_resp_valid   <= s1_valid;
            valid_branch_mask <= s1_prune_mask;

            if (s1_valid) begin
                logic [2:0]  max_idx;
                logic [15:0] max_score;
                max_idx   = 3'd0;
                max_score = s1_uct_scores[0];

                for (int i = 1; i < 8; i++) begin
                    if (s1_uct_scores[i] > max_score) begin
                        max_score = s1_uct_scores[i];
                        max_idx   = 3'(i);
                    end
                end
                best_branch_idx   <= max_idx;
                best_branch_score <= max_score;
            end
        end
    end

endmodule
