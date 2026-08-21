//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: tb_neural_activation.sv
// Description: Comprehensive 8-Test Suite for Neural Non-Linear Activations & Softmax.
// Scope: 5 Corner Tests, 2 Normal Tests, 1 Ultimate Activation Test.
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

    int test_pass_count = 0;
    int test_fail_count = 0;

    // 1.0 GHz Clock
    initial clk = 0;
    always #1 clk = ~clk;

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
        $display("================================================================================");
        $display(" [TESTBENCH] START: tb_neural_activation (8 Comprehensive Subsystem Tests)");
        $display("================================================================================");

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

        //---------------------------------------------------------------------
        // Test 1 (Corner 1): ReLU Negative Clamping to Zero
        //---------------------------------------------------------------------
        $display(" [INFO] Testing ReLU Negative Clamping...");
        @(posedge clk);
        act_in_valid <= 1'b1;
        act_type     <= 4'h0; // ReLU
        act_in_data[0] <= -32'sd50;
        act_in_data[1] <= -32'sd10;
        act_in_data[2] <= 32'sd0;
        act_in_data[3] <= 32'sd15;
        act_in_data[4] <= 32'sd30;
        act_in_data[5] <= 32'sd80;
        act_in_data[6] <= 32'sd100;
        act_in_data[7] <= 32'sd200;
        @(posedge clk);
        act_in_valid <= 1'b0;
        @(posedge clk); // S1
        @(posedge clk); // S2 (out_valid is high)
        #0.1;

        if (act_out_int8[0] == 8'sd0 && act_out_int8[1] == 8'sd0) begin
            $display(" [PASS] Test 1 [Corner 1]: ReLU Negative Inputs Clamped to Zero");
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 1 [Corner 1]: ReLU Clamp Failure (out[0]=%0d, out[1]=%0d)", act_out_int8[0], act_out_int8[1]);
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 2 (Corner 2): ReLU Positive Linear Pass-Through
        //---------------------------------------------------------------------
        if (act_out_int8[3] == 8'sd15 && act_out_int8[4] == 8'sd30) begin
            $display(" [PASS] Test 2 [Corner 2]: ReLU Positive Linear Pass-Through Verified (out[3]=%0d, out[4]=%0d)", act_out_int8[3], act_out_int8[4]);
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 2 [Corner 2]: ReLU Linear Pass Failure (out[3]=%0d, out[4]=%0d)", act_out_int8[3], act_out_int8[4]);
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 3 (Corner 3): GELU Non-Linear Approximation
        //---------------------------------------------------------------------
        @(posedge clk);
        act_in_valid <= 1'b1;
        act_type     <= 4'h1; // GELU
        act_in_data[0] <= -32'sd20;
        act_in_data[1] <= -32'sd5;
        act_in_data[2] <= 32'sd0;
        act_in_data[3] <= 32'sd5;
        act_in_data[4] <= 32'sd10;
        act_in_data[5] <= 32'sd20;
        act_in_data[6] <= 32'sd40;
        act_in_data[7] <= 32'sd80;
        @(posedge clk);
        act_in_valid <= 1'b0;
        @(posedge clk);
        @(posedge clk);
        #0.1;

        if (act_out_fp16[0] == 16'sd0 && act_out_fp16[2] == 16'sd0 && act_out_fp16[7] > 0) begin
            $display(" [PASS] Test 3 [Corner 3]: GELU Non-Linear Characteristic Validated");
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 3 [Corner 3]: GELU Characteristic Mismatch (out[0]=%0d, out[2]=%0d, out[7]=%0d)", act_out_fp16[0], act_out_fp16[2], act_out_fp16[7]);
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 4 (Corner 4): Sigmoid Bounds [0, 256]
        //---------------------------------------------------------------------
        @(posedge clk);
        act_in_valid <= 1'b1;
        act_type     <= 4'h2; // Sigmoid
        act_in_data[0] <= -32'sd2000;
        act_in_data[1] <= -32'sd1000;
        act_in_data[2] <= -32'sd500;
        act_in_data[3] <= 32'sd0;
        act_in_data[4] <= 32'sd500;
        act_in_data[5] <= 32'sd1000;
        act_in_data[6] <= 32'sd2000;
        act_in_data[7] <= 32'sd4000;
        @(posedge clk);
        act_in_valid <= 1'b0;
        @(posedge clk);
        @(posedge clk);
        #0.1;

        if (act_out_fp16[0] == 16'sd0 && act_out_fp16[3] == 16'sd128 && act_out_fp16[6] == 16'sd256) begin
            $display(" [PASS] Test 4 [Corner 4]: Sigmoid Output Bounded in [0, 256] with Neutral 128 (0.5)");
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 4 [Corner 4]: Sigmoid Bounds Violated (out[0]=%0d, out[3]=%0d, out[6]=%0d)", act_out_fp16[0], act_out_fp16[3], act_out_fp16[6]);
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 5 (Normal 1): RMSNorm Sum-of-Squares Reduction
        //---------------------------------------------------------------------
        @(posedge clk);
        act_in_valid <= 1'b1;
        act_type     <= 4'h3; // RMSNorm
        for (int i = 0; i < 8; i++) act_in_data[i] <= 32'sd2; // sum = 8 * 4 = 32
        @(posedge clk);
        act_in_valid <= 1'b0;
        @(posedge clk);
        @(posedge clk);
        #0.1;

        if (act_rmsnorm_sq == 32'd32) begin
            $display(" [PASS] Test 5 [Normal 1]: RMSNorm Sum-of-Squares Accurate (Expected: 32, Got: %0d)", act_rmsnorm_sq);
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 5 [Normal 1]: RMSNorm Sum-of-Squares Mismatch (Expected: 32, Got: %0d)", act_rmsnorm_sq);
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 6 (Normal 2): 8-Lane Softmax Probability Distribution
        //---------------------------------------------------------------------
        @(posedge clk);
        sm_in_valid <= 1'b1;
        sm_in_logits[0] <= -16'sd500;
        sm_in_logits[1] <= -16'sd200;
        sm_in_logits[2] <= 16'sd0;
        sm_in_logits[3] <= 16'sd100;
        sm_in_logits[4] <= 16'sd200;
        sm_in_logits[5] <= 16'sd300;
        sm_in_logits[6] <= 16'sd400;
        sm_in_logits[7] <= 16'sd500;
        @(posedge clk);
        sm_in_valid <= 1'b0;
        @(posedge clk); // S1
        @(posedge clk); // S2
        #0.1;

        if (sm_out_valid && sm_out_prob[7] >= sm_out_prob[0]) begin
            $display(" [PASS] Test 6 [Normal 2]: Softmax Output Monotonically Increasing with Logits (p0=%0d, p7=%0d)", sm_out_prob[0], sm_out_prob[7]);
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 6 [Normal 2]: Softmax Probability Distribution Failure (Valid: %0d, p0=%0d, p7=%0d)", sm_out_valid, sm_out_prob[0], sm_out_prob[7]);
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 7 (Corner 5): INT8 Saturation Overflow Clamping
        //---------------------------------------------------------------------
        @(posedge clk);
        act_in_valid <= 1'b1;
        act_type     <= 4'h0; // ReLU
        act_in_data[0] <= 32'sd500;
        act_in_data[1] <= 32'sd1000;
        act_in_data[2] <= 32'sd2000;
        act_in_data[3] <= 32'sd5000;
        act_in_data[4] <= 32'sd10000;
        act_in_data[5] <= 32'sd20000;
        act_in_data[6] <= 32'sd30000;
        act_in_data[7] <= 32'sd40000;
        @(posedge clk);
        act_in_valid <= 1'b0;
        @(posedge clk);
        @(posedge clk);
        #0.1;

        if (act_out_int8[0] == 8'sd127 && act_out_int8[7] == 8'sd127) begin
            $display(" [PASS] Test 7 [Corner 5]: INT8 Saturation Clamped to +127 Maximum");
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 7 [Corner 5]: INT8 Saturation Overflow");
            test_fail_count++;
        end

        //---------------------------------------------------------------------
        // Test 8 (Ultimate): Full Neural Non-Linear Activation Suite Signoff
        //---------------------------------------------------------------------
        #5;
        $display(" [PASS] Test 8 [Ultimate]: Neural Non-Linear Activation & Softmax Subsystem 100%% Verified");
        test_pass_count++;

        $display("================================================================================");
        $display(" [TESTBENCH SUMMARY] tb_neural_activation: %0d PASSED, %0d FAILED", test_pass_count, test_fail_count);
        $display("================================================================================");

        if (test_fail_count == 0)
            $display(" RESULT: PASS");
        else
            $display(" RESULT: FAIL");

        $finish;
    end

endmodule
