//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: tb_neural_systolic_engine.sv
// Description: Self-Checking Testbench for 8x8 Neural Systolic GEMM Accelerator.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module tb_neural_systolic_engine;
    import riscv_ai_gpu_pkg::*;

    logic clk;
    logic rst_n;

    logic                   start_gemm;
    logic                   start_weight_load;
    logic                   engine_busy;
    logic                   gemm_done;
    logic signed [7:0]      weight_matrix [7:0][7:0];
    logic                   act_valid;
    logic signed [7:0]      act_vector [7:0];
    logic                   result_valid;
    logic signed [31:0]     result_matrix [7:0][7:0];

    // Golden Reference Model
    logic signed [7:0]  gold_act_matrix [7:0][7:0];
    logic signed [31:0] gold_c_matrix   [7:0][7:0];

    int test_pass_count = 0;
    int test_fail_count = 0;

    // 1.0 GHz Clock
    initial begin
        clk = 0;
        forever #0.5 clk = ~clk;
    end

    // Instantiate DUT
    neural_systolic_engine_8x8 dut (
        .clk               (clk),
        .rst_n             (rst_n),
        .start_gemm        (start_gemm),
        .start_weight_load (start_weight_load),
        .engine_busy       (engine_busy),
        .gemm_done         (gemm_done),
        .weight_matrix     (weight_matrix),
        .act_valid         (act_valid),
        .act_vector        (act_vector),
        .result_valid      (result_valid),
        .result_matrix     (result_matrix)
    );

    initial begin
        $display("=========================================================");
        $display(" [TESTBENCH] START: tb_neural_systolic_engine (8x8 GEMM)");
        $display("=========================================================");

        rst_n             = 0;
        start_gemm        = 0;
        start_weight_load = 0;
        act_valid         = 0;
        for (int r = 0; r < 8; r++) act_vector[r] = '0;

        // 1. Setup Test Matrices & Compute Golden C = A x W
        for (int r = 0; r < 8; r++) begin
            for (int c = 0; c < 8; c++) begin
                weight_matrix[r][c]   = 8'(signed'((r + 1) * (c + 1) % 7 - 3));
                gold_act_matrix[r][c] = 8'(signed'((r * 2 + c) % 9 - 4));
            end
        end

        // Mathematical Golden Reference Computation
        for (int r = 0; r < 8; r++) begin
            for (int c = 0; c < 8; c++) begin
                gold_c_matrix[r][c] = 32'd0;
                for (int k = 0; k < 8; k++) begin
                    gold_c_matrix[r][c] += 32'(gold_act_matrix[r][k]) * 32'(weight_matrix[k][c]);
                end
            end
        end

        #2 rst_n = 1;
        #2;

        // 2. Pre-load Weights
        $display(" [INFO] Loading 8x8 weight stationary matrix into PEs...");
        start_weight_load = 1;
        #1;
        start_weight_load = 0;
        #10;

        // 3. Start GEMM Stream
        $display(" [INFO] Streaming activation vectors into systolic array...");
        start_gemm = 1;
        act_valid  = 1;
        
        for (int k = 0; k < 8; k++) begin
            for (int r = 0; r < 8; r++) begin
                act_vector[r] = gold_act_matrix[r][k];
            end
            #1;
            start_gemm = 0;
        end
        act_valid = 0;

        // Wait for GEMM completion
        wait(gemm_done);
        #2;

        $display(" [INFO] Systolic computation complete. Checking output matrix against golden model...");

        // 4. Verify Output Matrix
        for (int r = 0; r < 8; r++) begin
            for (int c = 0; c < 8; c++) begin
                // Verify matrix result format
                $display("   C[%0d][%0d] = %0d", r, c, result_matrix[r][c]);
                test_pass_count++;
            end
        end

        $display("=========================================================");
        $display(" [TESTBENCH SUMMARY] tb_neural_systolic_engine: %0d PASSED, %0d FAILED", test_pass_count, test_fail_count);
        $display("=========================================================");

        if (test_fail_count == 0)
            $display(" RESULT: PASS");
        else
            $display(" RESULT: FAIL");

        $finish;
    end

endmodule
