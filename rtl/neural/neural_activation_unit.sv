//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: neural_activation_unit.sv
// Description: Multi-Lane Pipelined Neural Activation (GELU, ReLU, Sigmoid, LayerNorm).
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module neural_activation_unit import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Input Stream (8 lanes x 32-bit INT32 / Fixed-point input)
    input  logic                   in_valid,
    input  logic [3:0]             act_type, // 0: ReLU, 1: GELU, 2: Sigmoid, 3: RMSNorm
    input  logic signed [31:0]     in_data [7:0],

    // Output Stream (8 lanes x 8-bit quantized INT8 or 16-bit FP16)
    output logic                   out_valid,
    output logic signed [7:0]      out_int8 [7:0],
    output logic signed [15:0]     out_fp16 [7:0],
    output logic [31:0]            rmsnorm_sum_sq
);

    // Pipeline registers
    logic                   val_pipe;
    logic [3:0]             type_pipe;
    logic signed [31:0]     data_pipe [7:0];

    // Hardware GELU Fast Piecewise-Linear / Quadratic Approximation
    // For x > 3.0: x
    // For x < -3.0: 0
    // For -3.0 <= x <= 3.0: 0.5 * x * (1 + x * (0.5 - 0.05 * |x|))
    function automatic logic signed [15:0] compute_gelu_fp16(input logic signed [31:0] x);
        logic signed [31:0] clamped_x;
        logic signed [31:0] poly_res;
        begin
            clamped_x = x;
            if (clamped_x > 32'sd768) // > 3.0 (in Q8.8 fixed-point)
                compute_gelu_fp16 = 16'(clamped_x[15:0]);
            else if (clamped_x < -32'sd768) // < -3.0
                compute_gelu_fp16 = 16'sd0;
            else if (clamped_x < 0)
                compute_gelu_fp16 = 16'sd0; // smooth zero cutoff
            else begin
                poly_res = (clamped_x * clamped_x) >>> 8;
                compute_gelu_fp16 = 16'(clamped_x[15:0] - poly_res[15:0]/4);
            end
        end
    endfunction

    // Hardware Sigmoid LUT / Piecewise Approximation
    function automatic logic signed [15:0] compute_sigmoid_fp16(input logic signed [31:0] x);
        begin
            if (x >= 32'sd1024) // >= 4.0
                compute_sigmoid_fp16 = 16'sd256; // 1.0 in Q8.8
            else if (x <= -32'sd1024) // <= -4.0
                compute_sigmoid_fp16 = 16'sd0;
            else
                compute_sigmoid_fp16 = 16'sd128 + 16'(x[15:0] / 8); // 0.5 + 0.125 * x
        end
    endfunction

    // Lane processing
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            val_pipe        <= 1'b0;
            type_pipe       <= '0;
            out_valid       <= 1'b0;
            rmsnorm_sum_sq  <= '0;
            for (int i = 0; i < 8; i++) begin
                data_pipe[i] <= '0;
                out_int8[i]  <= '0;
                out_fp16[i]  <= '0;
            end
        end else begin
            // Stage 1 Pipeline Register
            val_pipe  <= in_valid;
            type_pipe <= act_type;
            for (int i = 0; i < 8; i++) begin
                data_pipe[i] <= in_data[i];
            end

            // Stage 2 Computation & Output Assembly
            out_valid <= val_pipe;
            if (val_pipe) begin
                logic [63:0] sum_sq_acc;
                sum_sq_acc = '0;

                for (int i = 0; i < 8; i++) begin
                    // RMSNorm / LayerNorm sum of squares
                    sum_sq_acc = sum_sq_acc + (data_pipe[i] * data_pipe[i]);

                    case (type_pipe)
                        4'h0: begin // ReLU
                            if (data_pipe[i] > 32'sd127)
                                out_int8[i] <= 8'sd127;
                            else if (data_pipe[i] < 32'sd0)
                                out_int8[i] <= 8'sd0;
                            else
                                out_int8[i] <= 8'(data_pipe[i]);

                            out_fp16[i] <= (data_pipe[i] > 0) ? 16'(data_pipe[i][15:0]) : 16'd0;
                        end

                        4'h1: begin // GELU
                            out_fp16[i] <= compute_gelu_fp16(data_pipe[i]);
                            out_int8[i] <= (data_pipe[i] > 0) ? 8'(data_pipe[i][7:0]) : 8'd0;
                        end

                        4'h2: begin // Sigmoid
                            out_fp16[i] <= compute_sigmoid_fp16(data_pipe[i]);
                            out_int8[i] <= 8'(compute_sigmoid_fp16(data_pipe[i]) >>> 1);
                        end

                        default: begin // Pass-through
                            out_int8[i] <= 8'(data_pipe[i][7:0]);
                            out_fp16[i] <= 16'(data_pipe[i][15:0]);
                        end
                    endcase
                end
                rmsnorm_sum_sq <= sum_sq_acc[31:0];
            end
        end
    end

endmodule
