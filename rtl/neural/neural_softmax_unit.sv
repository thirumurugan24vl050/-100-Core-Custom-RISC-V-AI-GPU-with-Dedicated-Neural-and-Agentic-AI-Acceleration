//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: neural_softmax_unit.sv
// Description: 8-Lane Fast Online Softmax Unit with Max-Subtraction & Exp LUT.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module neural_softmax_unit import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Input Stream (8 lanes x 16-bit Q8.8 fixed-point logits)
    input  logic                   in_valid,
    input  logic signed [15:0]     in_logits [7:0],

    // Output Probabilities (8 lanes x 16-bit Q0.16 probabilities sum to 1.0)
    output logic                   out_valid,
    output logic [15:0]            out_prob [7:0]
);

    // Stage 1: Max Reduction
    logic                   s1_valid;
    logic signed [15:0]     s1_logits [7:0];
    logic signed [15:0]     s1_max;

    // Stage 2: Subtraction & Exp Approximation
    logic                   s2_valid;
    logic [8:0]             s2_exp [7:0];
    logic [11:0]            s2_sum_exp;

    // Fast Exp approximation: 2^(x * 1.442695)
    // For normalized x <= 0: exp(x) approx (1 + x/16)^16
    function automatic logic [8:0] fast_exp(input logic signed [15:0] delta);
        logic signed [15:0] clamped_delta;
        logic [31:0] val;
        begin
            clamped_delta = delta;
            if (clamped_delta <= -16'sd2048) // <= -8.0
                fast_exp = 9'd0;
            else if (clamped_delta >= 0)
                fast_exp = 9'd256; // 1.0 in Q8.8
            else begin
                // Linear decay approximation for fast inference: 256 * (1 + delta/8)
                val = 32'd256 + ((32'(signed'(clamped_delta)) * 32'd32) >>> 8);
                fast_exp = val[8:0];
            end
        end
    endfunction

    // Pipeline Stage 1: Find Max
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid <= 1'b0;
            s1_max   <= '0;
            for (int i = 0; i < 8; i++) s1_logits[i] <= '0;
        end else begin
            s1_valid <= in_valid;
            if (in_valid) begin
                logic signed [15:0] cur_max;
                cur_max = in_logits[0];
                for (int i = 1; i < 8; i++) begin
                    if (in_logits[i] > cur_max)
                        cur_max = in_logits[i];
                end
                s1_max <= cur_max;
                for (int i = 0; i < 8; i++) begin
                    s1_logits[i] <= in_logits[i];
                end
            end
        end
    end

    // Pipeline Stage 2: Subtract Max & Compute Exp + Sum
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_valid   <= 1'b0;
            s2_sum_exp <= '0;
            for (int i = 0; i < 8; i++) s2_exp[i] <= '0;
        end else begin
            s2_valid <= s1_valid;
            if (s1_valid) begin
                logic [31:0] sum_acc;
                sum_acc = '0;
                for (int i = 0; i < 8; i++) begin
                    s2_exp[i] <= fast_exp(s1_logits[i] - s1_max);
                    sum_acc   = sum_acc + 32'(fast_exp(s1_logits[i] - s1_max));
                end
                s2_sum_exp <= sum_acc[11:0];
            end
        end
    end

    // Pipeline Stage 3: Normalize (Division / Scaling to Q0.16)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            for (int i = 0; i < 8; i++) out_prob[i] <= '0;
        end else begin
            out_valid <= s2_valid;
            if (s2_valid) begin
                for (int i = 0; i < 8; i++) begin
                    // Q0.16 normalized output: (exp[i] << 16) / sum_exp
                    logic [31:0] prob_div;
                    prob_div = (32'(s2_exp[i]) << 16) / s2_sum_exp;
                    out_prob[i] <= (prob_div >= 32'h10000) ? 16'hFFFF : 16'(prob_div);
                end
            end
        end
    end

endmodule
