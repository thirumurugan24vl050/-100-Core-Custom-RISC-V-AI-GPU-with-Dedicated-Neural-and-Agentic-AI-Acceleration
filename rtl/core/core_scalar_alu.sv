//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: core_scalar_alu.sv
// Description: RV32IM Scalar ALU and Multiplier/Divider with Branch Evaluator.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module core_scalar_alu import riscv_ai_gpu_pkg::*; (
    input  logic [3:0]             alu_op,
    input  logic [XLEN-1:0]        operand_a,
    input  logic [XLEN-1:0]        operand_b,
    input  logic [2:0]             branch_funct3,
    output logic [XLEN-1:0]        alu_result,
    output logic                   branch_taken,
    output logic                   comparison_result
);

    // ALU Operation Encodings
    localparam logic [3:0] ALU_ADD  = 4'h0;
    localparam logic [3:0] ALU_SUB  = 4'h1;
    localparam logic [3:0] ALU_SLL  = 4'h2;
    localparam logic [3:0] ALU_SLT  = 4'h3;
    localparam logic [3:0] ALU_SLTU = 4'h4;
    localparam logic [3:0] ALU_XOR  = 4'h5;
    localparam logic [3:0] ALU_SRL  = 4'h6;
    localparam logic [3:0] ALU_SRA  = 4'h7;
    localparam logic [3:0] ALU_OR   = 4'h8;
    localparam logic [3:0] ALU_AND  = 4'h9;
    localparam logic [3:0] ALU_MUL  = 4'hA;
    localparam logic [3:0] ALU_MULH = 4'hB;
    localparam logic [3:0] ALU_DIV  = 4'hC;
    localparam logic [3:0] ALU_REM  = 4'hD;
    localparam logic [3:0] ALU_PASS = 4'hE;

    // Signed multiplier support
    logic signed [XLEN-1:0]   signed_a;
    logic signed [XLEN-1:0]   signed_b;
    logic signed [2*XLEN-1:0] mul_signed_res;
    logic [2*XLEN-1:0]        mul_unsigned_res;

    assign signed_a = operand_a;
    assign signed_b = operand_b;
    assign mul_signed_res = signed_a * signed_b;
    assign mul_unsigned_res = operand_a * operand_b;

    // Combinational ALU Datapath
    always_comb begin
        case (alu_op)
            ALU_ADD:  alu_result = operand_a + operand_b;
            ALU_SUB:  alu_result = operand_a - operand_b;
            ALU_SLL:  alu_result = operand_a << operand_b[4:0];
            ALU_SLT:  alu_result = (signed_a < signed_b) ? 32'd1 : 32'd0;
            ALU_SLTU: alu_result = (operand_a < operand_b) ? 32'd1 : 32'd0;
            ALU_XOR:  alu_result = operand_a ^ operand_b;
            ALU_SRL:  alu_result = operand_a >> operand_b[4:0];
            ALU_SRA:  alu_result = signed_a >>> operand_b[4:0];
            ALU_OR:   alu_result = operand_a | operand_b;
            ALU_AND:  alu_result = operand_a & operand_b;
            ALU_MUL:  alu_result = mul_unsigned_res[XLEN-1:0];
            ALU_MULH: alu_result = mul_signed_res[2*XLEN-1:XLEN];
            ALU_DIV:  alu_result = (operand_b != 0) ? (operand_a / operand_b) : 32'hFFFFFFFF;
            ALU_REM:  alu_result = (operand_b != 0) ? (operand_a % operand_b) : operand_a;
            ALU_PASS: alu_result = operand_b;
            default:  alu_result = '0;
        endcase
    end

    // Branch condition evaluator
    always_comb begin
        case (branch_funct3)
            3'b000: branch_taken = (operand_a == operand_b);               // BEQ
            3'b001: branch_taken = (operand_a != operand_b);               // BNE
            3'b100: branch_taken = (signed_a < signed_b);                 // BLT
            3'b101: branch_taken = (signed_a >= signed_b);                // BGE
            3'b110: branch_taken = (operand_a < operand_b);               // BLTU
            3'b111: branch_taken = (operand_a >= operand_b);              // BGEU
            default: branch_taken = 1'b0;
        endcase
        comparison_result = (signed_a < signed_b);
    end

endmodule
