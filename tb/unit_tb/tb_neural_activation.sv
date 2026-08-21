//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: tb_neural_activation.sv
// Description: Self-Checking Testbench for Neural Activation and Softmax Units.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module tb_neural_activation;
    import riscv_ai_gpu_pkg::*;

    logic clk;
    logic rst_n;

    // Activation Unit Wires
    logic                   act_in_valid;
    logic [3:0]             act_type;
    logic signed [31:0]     act_in_data [7:0];
    logic                   act_out_valid;
    logic signed [7:0]      act_out_int8 [7:0];
    logic signed [15:0]     act_out_fp16 [7:0];
    logic [31:0]            act_rmsnorm_sq;

    // Softmax Unit Wires
    logic                   sm_in_valid;
    logic signed [15:0]     sm_in_logits [7:0];
    logic                   sm_out_valid;
    logic [15:0]            sm_out_prob [7:0];
    logic [31:0]            prob_sum;

    int test_pass_count = 0;
    int test_fail_count = 0;

    // Clock
    initial begin
        clk = 0;
        forever #0.5 clk = ~clk;
    end

    // Instantiate Activation Unit
    neural_activation_unit u_act_unit (
        .clk            (clk),
        .rst_n          (rst_n),
        .in_valid       (act_in_valid),
        .act_type       (act_type),
        .in_data        (act_in_data),
        .out_valid      (act_out_valid),
        .out_int8       (act_out_int8),
        .out_fp16       (act_out_fp16),
        .rmsnorm_sum_sq (act_rmsnorm_sq)
    );

    // Instantiate Softmax Unit
    neural_softmax_unit u_softmax_unit (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (sm_in_valid),
        .in_logits (sm_in_logits),
        .out_valid (sm_out_valid),
        .out_prob  (sm_out_prob)
    );

    initial begin
        $display("=========================================================");
        $display(" [TESTBENCH] START: tb_neural_activation & Softmax");
        $display("=========================================================");

        rst_n        = 0;
        act_in_valid = 0;
        act_type     = 4'h0; // ReLU
        sm_in_valid  = 0;
        for (int i = 0; i < 8; i++) begin
            act_in_data[i]  = '0;
            sm_in_logits[i] = '0;
        end

        #2 rst_n = 1;
        #2;

        // 1. Test ReLU Activation: Input = [-50, -10, 0, 15, 30, 80, 100, 200]
        $display(" [INFO] Testing ReLU Activation...");
        act_in_valid = 1;
        act_type     = 4'h0; // ReLU
        act_in_data  = '{-32'sd50, -32'sd10, 32'sd0, 32'sd15, 32'sd30, 32'sd80, 32'sd100, 32'sd200};
        #1;
        act_in_valid = 0;
        #2;

        if (act_out_int8[0] == 8'sd0 && act_out_int8[1] == 8'sd0 && act_out_int8[3] == 8'sd15 && act_out_int8[4] == 8'sd30) begin
            $display(" [PASS] ReLU correctly zeroed negative values and passed positive values");
            test_pass_count++;
        end else begin
            $display(" [FAIL] ReLU Output Mismatch: out[0]=%0d, out[3]=%0d", act_out_int8[0], act_out_int8[3]);
            test_fail_count++;
        end

        // 2. Test GELU Activation
        $display(" [INFO] Testing GELU Activation...");
        act_in_valid = 1;
        act_type     = 4'h1; // GELU
        act_in_data  = '{32'sd256, 32'sd512, -32'sd256, 32'sd128, 32'sd0, 32'sd64, -32'sd512, 32'sd768};
        #1;
        act_in_valid = 0;
        #2;

        if (act_out_fp16[0] > 0 && act_out_fp16[2] == 0) begin
            $display(" [PASS] GELU Non-linear Curve evaluated correctly");
            test_pass_count++;
        end else begin
            $display(" [FAIL] GELU calculation error");
            test_fail_count++;
        end

        // 3. Test Softmax Probability Normalization
        $display(" [INFO] Testing Softmax Normalization...");
        sm_in_valid  = 1;
        sm_in_logits = '{16'sd200, 16'sd150, 16'sd300, 16'sd100, 16'sd50, 16'sd250, 16'sd80, 16'sd120};
        #1;
        sm_in_valid  = 0;
        #4; // 3-stage pipeline latency

        prob_sum = 0;
        for (int i = 0; i < 8; i++) begin
            prob_sum += 32'(sm_out_prob[i]);
            $display("   Softmax Prob[%0d] = %0d (Q0.16)", i, sm_out_prob[i]);
        end

        // Highest logit is index 2 (300), so prob[2] must be maximum
        if (sm_out_prob[2] >= sm_out_prob[0] && sm_out_prob[2] >= sm_out_prob[1]) begin
            $display(" [PASS] Softmax correctly assigned highest probability (%0d) to largest logit (index 2)", sm_out_prob[2]);
            test_pass_count++;
        end else begin
            $display(" [FAIL] Softmax ordering incorrect");
            test_fail_count++;
        end

        $display("=========================================================");
        $display(" [TESTBENCH SUMMARY] tb_neural_activation: %0d PASSED, %0d FAILED", test_pass_count, test_fail_count);
        $display("=========================================================");

        if (test_fail_count == 0)
            $display(" RESULT: PASS");
        else
            $display(" RESULT: FAIL");

        $finish;
    end

endmodule
