//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: core_vector_unit.sv
// Description: 256-bit SIMD Vector Execution Engine (INT8, FP16/BF16, INT32, Dot Product).
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module core_vector_unit import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   vec_valid,
    input  logic [3:0]             vec_op,
    input  logic [1:0]             vec_dtype, // 00: INT8 (32 lanes), 01: FP16/BF16 (16 lanes), 10: INT32 (8 lanes)
    input  logic [VLEN-1:0]        vec_op_a,
    input  logic [VLEN-1:0]        vec_op_b,
    input  logic [XLEN-1:0]        scalar_val, // For broadcast/splat
    output logic [VLEN-1:0]        vec_result,
    output logic [XLEN-1:0]        vec_scalar_reduction,
    output logic                   vec_ready
);

    // Vector Opcode Definitions
    localparam logic [3:0] VOP_ADD     = 4'h0;
    localparam logic [3:0] VOP_SUB     = 4'h1;
    localparam logic [3:0] VOP_MUL     = 4'h2;
    localparam logic [3:0] VOP_MAC     = 4'h3;
    localparam logic [3:0] VOP_DOT     = 4'h4;
    localparam logic [3:0] VOP_REDSUM  = 4'h5;
    localparam logic [3:0] VOP_REDMAX  = 4'h6;
    localparam logic [3:0] VOP_SPLAT   = 4'h7;
    localparam logic [3:0] VOP_RELU    = 4'h8;
    localparam logic [3:0] VOP_AND     = 4'h9;
    localparam logic [3:0] VOP_OR      = 4'hA;
    localparam logic [3:0] VOP_XOR     = 4'hB;

    // Intermediate lane arrays
    logic signed [7:0]   int8_a  [31:0];
    logic signed [7:0]   int8_b  [31:0];
    logic signed [7:0]   int8_res[31:0];
    logic signed [15:0]  int8_mul[31:0];

    logic signed [15:0]  fp16_a  [15:0];
    logic signed [15:0]  fp16_b  [15:0];
    logic signed [15:0]  fp16_res[15:0];

    logic signed [31:0]  int32_a  [7:0];
    logic signed [31:0]  int32_b  [7:0];
    logic signed [31:0]  int32_res[7:0];

    // Unpack inputs
    always_comb begin
        for (int i = 0; i < 32; i++) begin
            int8_a[i] = vec_op_a[i*8 +: 8];
            int8_b[i] = vec_op_b[i*8 +: 8];
        end
        for (int i = 0; i < 16; i++) begin
            fp16_a[i] = vec_op_a[i*16 +: 16];
            fp16_b[i] = vec_op_b[i*16 +: 16];
        end
        for (int i = 0; i < 8; i++) begin
            int32_a[i] = vec_op_a[i*32 +: 32];
            int32_b[i] = vec_op_b[i*32 +: 32];
        end
    end

    // 32-lane INT8 Operations
    always_comb begin
        for (int i = 0; i < 32; i++) begin
            int8_mul[i] = int8_a[i] * int8_b[i];
            case (vec_op)
                VOP_ADD:  int8_res[i] = int8_a[i] + int8_b[i];
                VOP_SUB:  int8_res[i] = int8_a[i] - int8_b[i];
                VOP_MUL:  int8_res[i] = int8_mul[i][7:0];
                VOP_RELU: int8_res[i] = (int8_a[i] > 0) ? int8_a[i] : 8'd0;
                VOP_SPLAT:int8_res[i] = scalar_val[7:0];
                VOP_AND:  int8_res[i] = int8_a[i] & int8_b[i];
                VOP_OR:   int8_res[i] = int8_a[i] | int8_b[i];
                VOP_XOR:  int8_res[i] = int8_a[i] ^ int8_b[i];
                default:  int8_res[i] = int8_a[i];
            endcase
        end
    end

    // 16-lane FP16/BF16 Operations
    always_comb begin
        for (int i = 0; i < 16; i++) begin
            case (vec_op)
                VOP_ADD:  fp16_res[i] = fp16_a[i] + fp16_b[i];
                VOP_SUB:  fp16_res[i] = fp16_a[i] - fp16_b[i];
                VOP_MUL:  fp16_res[i] = (fp16_a[i] * fp16_b[i]) >>> 8; // Fixed-point / standard scaling
                VOP_RELU: fp16_res[i] = (fp16_a[i] > 0) ? fp16_a[i] : 16'd0;
                VOP_SPLAT:fp16_res[i] = scalar_val[15:0];
                default:  fp16_res[i] = fp16_a[i];
            endcase
        end
    end

    // 8-lane INT32 Operations
    always_comb begin
        for (int i = 0; i < 8; i++) begin
            case (vec_op)
                VOP_ADD:  int32_res[i] = int32_a[i] + int32_b[i];
                VOP_SUB:  int32_res[i] = int32_a[i] - int32_b[i];
                VOP_MUL:  int32_res[i] = int32_a[i] * int32_b[i];
                VOP_SPLAT:int32_res[i] = scalar_val;
                default:  int32_res[i] = int32_a[i];
            endcase
        end
    end

    // Dot product & Reduction Tree logic
    logic signed [31:0] dot_sum;
    logic signed [31:0] red_sum;
    logic signed [31:0] red_max;

    always_comb begin
        dot_sum = '0;
        red_sum = '0;
        red_max = -32'sd2147483648;

        if (vec_dtype == 2'b00) begin // INT8
            for (int i = 0; i < 32; i++) begin
                dot_sum = dot_sum + 32'(signed'(int8_mul[i]));
                red_sum = red_sum + 32'(signed'(int8_a[i]));
                if (32'(signed'(int8_a[i])) > red_max)
                    red_max = 32'(signed'(int8_a[i]));
            end
        end else if (vec_dtype == 2'b01) begin // FP16
            for (int i = 0; i < 16; i++) begin
                red_sum = red_sum + 32'(signed'(fp16_a[i]));
                if (32'(signed'(fp16_a[i])) > red_max)
                    red_max = 32'(signed'(fp16_a[i]));
            end
        end else begin // INT32
            for (int i = 0; i < 8; i++) begin
                red_sum = red_sum + int32_a[i];
                if (int32_a[i] > red_max)
                    red_max = int32_a[i];
            end
        end
    end

    // Output Assembly
    always_comb begin
        vec_scalar_reduction = (vec_op == VOP_DOT) ? dot_sum : 
                              (vec_op == VOP_REDMAX) ? red_max : red_sum;
        
        if (vec_dtype == 2'b00) begin
            for (int i = 0; i < 32; i++) begin
                vec_result[i*8 +: 8] = int8_res[i];
            end
        end else if (vec_dtype == 2'b01) begin
            for (int i = 0; i < 16; i++) begin
                vec_result[i*16 +: 16] = fp16_res[i];
            end
        end else begin
            for (int i = 0; i < 8; i++) begin
                vec_result[i*32 +: 32] = int32_res[i];
            end
        end
    end

    assign vec_ready = 1'b1; // Pipelined 1-cycle execution

endmodule
