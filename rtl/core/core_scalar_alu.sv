//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: core_scalar_alu.sv
// Description: Full RV32IM Scalar ALU + Multiplier/Divider with Branch Evaluator.
//              Supports all 37 RV32I scalar ALU/Branch ops + ALL 8 RV32M ops:
//              MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module core_scalar_alu import riscv_ai_gpu_pkg::*; (
    input  logic [4:0]             alu_op,
    input  logic [XLEN-1:0]        operand_a,
    input  logic [XLEN-1:0]        operand_b,
    input  logic [2:0]             branch_funct3,
    output logic [XLEN-1:0]        alu_result,
    output logic                   branch_taken,
    output logic                   comparison_result
);

    // ALU Operation Encodings (5-bit width for full RV32IM support)
    localparam logic [4:0] ALU_ADD    = 5'h00;
    localparam logic [4:0] ALU_SUB    = 5'h01;
    localparam logic [4:0] ALU_SLL    = 5'h02;
    localparam logic [4:0] ALU_SLT    = 5'h03;
    localparam logic [4:0] ALU_SLTU   = 5'h04;
    localparam logic [4:0] ALU_XOR    = 5'h05;
    localparam logic [4:0] ALU_SRL    = 5'h06;
    localparam logic [4:0] ALU_SRA    = 5'h07;
    localparam logic [4:0] ALU_OR     = 5'h08;
    localparam logic [4:0] ALU_AND    = 5'h09;

    // RV32M Multiply Operations
    localparam logic [4:0] ALU_MUL    = 5'h0A; // Signed x Signed lower 32b
    localparam logic [4:0] ALU_MULH   = 5'h0B; // Signed x Signed upper 32b
    localparam logic [4:0] ALU_MULHSU = 5'h0C; // Signed x Unsigned upper 32b
    localparam logic [4:0] ALU_MULHU  = 5'h0D; // Unsigned x Unsigned upper 32b

    // RV32M Divide / Remainder Operations
    localparam logic [4:0] ALU_DIV    = 5'h0E; // Signed divide
    localparam logic [4:0] ALU_DIVU   = 5'h0F; // Unsigned divide
    localparam logic [4:0] ALU_REM    = 5'h10; // Signed remainder
    localparam logic [4:0] ALU_REMU   = 5'h11; // Unsigned remainder
    localparam logic [4:0] ALU_PASS   = 5'h12; // Pass operand_b (LUI)

    // Signed multiplier signals
    logic signed [XLEN-1:0]   signed_a;
    logic signed [XLEN-1:0]   signed_b;
    logic signed [2*XLEN-1:0] mul_ss_res;  // Signed x Signed
    logic signed [2*XLEN-1:0] mul_su_res;  // Signed x Unsigned
    logic [2*XLEN-1:0]        mul_uu_res;  // Unsigned x Unsigned

    assign signed_a = operand_a;
    assign signed_b = operand_b;
    assign mul_ss_res = signed_a * signed_b;
    assign mul_su_res = signed_a * $signed({1'b0, operand_b});
    assign mul_uu_res = operand_a * operand_b;

    // Special case overflow detection for signed division: -2^31 / -1
    logic div_overflow;
    assign div_overflow = (signed_a == 32'h80000000) && (signed_b == -32'sd1);

    // Combinational ALU Datapath
    always_comb begin
        case (alu_op)
            ALU_ADD:    alu_result = operand_a + operand_b;
            ALU_SUB:    alu_result = operand_a - operand_b;
            ALU_SLL:    alu_result = operand_a << operand_b[4:0];
            ALU_SLT:    alu_result = (signed_a < signed_b) ? 32'd1 : 32'd0;
            ALU_SLTU:   alu_result = (operand_a < operand_b) ? 32'd1 : 32'd0;
            ALU_XOR:    alu_result = operand_a ^ operand_b;
            ALU_SRL:    alu_result = operand_a >> operand_b[4:0];
            ALU_SRA:    alu_result = signed_a >>> operand_b[4:0];
            ALU_OR:     alu_result = operand_a | operand_b;
            ALU_AND:    alu_result = operand_a & operand_b;

            // RV32M Multiplies
            ALU_MUL:    alu_result = mul_uu_res[XLEN-1:0];
            ALU_MULH:   alu_result = mul_ss_res[2*XLEN-1:XLEN];
            ALU_MULHSU: alu_result = mul_su_res[2*XLEN-1:XLEN];
            ALU_MULHU:  alu_result = mul_uu_res[2*XLEN-1:XLEN];

            // RV32M Divides (RISC-V spec compliant divide-by-zero & overflow behavior)
            ALU_DIV: begin
                if (operand_b == 32'd0)
                    alu_result = 32'hFFFFFFFF; // Divide by zero returns -1
                else if (div_overflow)
                    alu_result = 32'h80000000; // Overflow returns -2^31
                else
                    alu_result = signed_a / signed_b;
            end
            ALU_DIVU: begin
                if (operand_b == 32'd0)
                    alu_result = 32'hFFFFFFFF; // Divide by zero returns 2^32 - 1
                else
                    alu_result = operand_a / operand_b;
            end
            ALU_REM: begin
                if (operand_b == 32'd0)
                    alu_result = operand_a;    // Remainder by zero returns operand_a
                else if (div_overflow)
                    alu_result = 32'd0;         // Overflow returns 0
                else
                    alu_result = signed_a % signed_b;
            end
            ALU_REMU: begin
                if (operand_b == 32'd0)
                    alu_result = operand_a;    // Remainder by zero returns operand_a
                else
                    alu_result = operand_a % operand_b;
            end

            ALU_PASS:   alu_result = operand_b;
            default:    alu_result = '0;
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
