//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: core_decode_unit.sv
// Description: Complete Instruction Decoder for 69 Defined Operations:
//              - 37 RV32I Base Scalar Instructions
//              - 8 RV32M Multiply/Divide Instructions
//              - 6 CUSTOM-0 Tensor/Neural Accelerator Instructions
//              - 12 CUSTOM-1 SIMD Vector Instructions (funct7[6]=0)
//              - 6 CUSTOM-1 Agentic/Sync/Fence Instructions (funct7[6]=1)
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module core_decode_unit import riscv_ai_gpu_pkg::*; (
    input  logic [31:0]            instruction,
    input  logic [XLEN-1:0]        pc_in,
    input  logic [1:0]             warp_id_in,

    // Decoded Register and Immediate Fields
    output logic [1:0]             warp_id_out,
    output logic [4:0]             rs1_addr,
    output logic [4:0]             rs2_addr,
    output logic [4:0]             rd_addr,
    output logic                   reg_write_en,
    output logic                   vec_write_en,
    output logic [XLEN-1:0]        imm_val,

    // Unit Dispatch Enablers
    output logic                   is_scalar_op,
    output logic                   is_vector_op,
    output logic                   is_neural_op,
    output logic                   is_agentic_op,
    output logic                   is_load,
    output logic                   is_store,
    output logic                   is_branch,
    output logic                   is_jump,
    output logic                   is_csr,
    output logic                   is_barrier,
    output logic                   is_fence,
    output logic                   is_yield,

    // Specific sub-opcodes
    output logic [4:0]             scalar_alu_op,
    output logic [3:0]             vector_op,
    output logic [1:0]             vector_dtype,
    output logic [3:0]             neural_op,
    output logic [3:0]             agentic_op,
    output logic [1:0]             fence_scope,
    output logic [2:0]             funct3_out,
    output logic [11:0]            csr_addr,
    output logic                   illegal_instruction
);

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode      = instruction[6:0];
    assign rd_addr     = instruction[11:7];
    assign funct3      = instruction[14:12];
    assign rs1_addr    = instruction[19:15];
    assign rs2_addr    = instruction[24:20];
    assign funct7      = instruction[31:25];
    assign warp_id_out = warp_id_in;
    assign funct3_out  = funct3;
    assign csr_addr    = instruction[31:20];
    assign fence_scope = funct7[1:0];

    // Immediate decoding
    always_comb begin
        case (opcode)
            7'b0110111, 7'b0010111: // LUI, AUIPC (U-type)
                imm_val = {instruction[31:12], 12'h000};
            7'b1101111: // JAL (J-type)
                imm_val = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
            7'b1100011: // Branch (B-type)
                imm_val = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
            7'b0100011: // Store (S-type)
                imm_val = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            default: // I-type (Loads, OP-IMM, JALR)
                imm_val = {{20{instruction[31]}}, instruction[31:20]};
        endcase
    end

    // Instruction decoding logic
    always_comb begin
        // Defaults
        reg_write_en        = 1'b0;
        vec_write_en        = 1'b0;
        is_scalar_op        = 1'b0;
        is_vector_op        = 1'b0;
        is_neural_op        = 1'b0;
        is_agentic_op       = 1'b0;
        is_load             = 1'b0;
        is_store            = 1'b0;
        is_branch           = 1'b0;
        is_jump             = 1'b0;
        is_csr              = 1'b0;
        is_barrier          = 1'b0;
        is_fence            = 1'b0;
        is_yield            = 1'b0;
        scalar_alu_op       = 5'h00;
        vector_op           = 4'h0;
        vector_dtype        = 2'b00;
        neural_op           = 4'h0;
        agentic_op          = 4'h0;
        illegal_instruction = 1'b0;

        case (opcode)
            // 1. OP-IMM (ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI)
            7'b0010011: begin
                is_scalar_op = 1'b1;
                reg_write_en = (rd_addr != 5'd0);
                case (funct3)
                    3'b000: scalar_alu_op = 5'h00; // ADDI
                    3'b010: scalar_alu_op = 5'h03; // SLTI
                    3'b011: scalar_alu_op = 5'h04; // SLTIU
                    3'b100: scalar_alu_op = 5'h05; // XORI
                    3'b110: scalar_alu_op = 5'h08; // ORI
                    3'b111: scalar_alu_op = 5'h09; // ANDI
                    3'b001: scalar_alu_op = 5'h02; // SLLI
                    3'b101: scalar_alu_op = (funct7[5]) ? 5'h07 : 5'h06; // SRAI / SRLI
                    default: illegal_instruction = 1'b1;
                endcase
            end

            // 2. OP (ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND + 8 RV32M ops)
            7'b0110011: begin
                is_scalar_op = 1'b1;
                reg_write_en = (rd_addr != 5'd0);
                if (funct7 == 7'b0000001) begin // All 8 RV32M Multiply/Divide Operations
                    case (funct3)
                        3'b000: scalar_alu_op = 5'h0A; // MUL
                        3'b001: scalar_alu_op = 5'h0B; // MULH
                        3'b010: scalar_alu_op = 5'h0C; // MULHSU
                        3'b011: scalar_alu_op = 5'h0D; // MULHU
                        3'b100: scalar_alu_op = 5'h0E; // DIV
                        3'b101: scalar_alu_op = 5'h0F; // DIVU
                        3'b110: scalar_alu_op = 5'h10; // REM
                        3'b111: scalar_alu_op = 5'h11; // REMU
                        default: illegal_instruction = 1'b1;
                    endcase
                end else if (funct7 == 7'b0000000 || funct7 == 7'b0100000) begin // Standard Base ALU
                    case (funct3)
                        3'b000: scalar_alu_op = (funct7[5]) ? 5'h01 : 5'h00; // SUB / ADD
                        3'b001: scalar_alu_op = 5'h02; // SLL
                        3'b010: scalar_alu_op = 5'h03; // SLT
                        3'b011: scalar_alu_op = 5'h04; // SLTU
                        3'b100: scalar_alu_op = 5'h05; // XOR
                        3'b101: scalar_alu_op = (funct7[5]) ? 5'h07 : 5'h06; // SRA / SRL
                        3'b110: scalar_alu_op = 5'h08; // OR
                        3'b111: scalar_alu_op = 5'h09; // AND
                        default: illegal_instruction = 1'b1;
                    endcase
                end else begin
                    illegal_instruction = 1'b1;
                end
            end

            // 3. LUI / AUIPC
            7'b0110111: begin // LUI
                is_scalar_op = 1'b1;
                reg_write_en = (rd_addr != 5'd0);
                scalar_alu_op = 5'h12; // PASS imm
            end
            7'b0010111: begin // AUIPC
                is_scalar_op = 1'b1;
                reg_write_en = (rd_addr != 5'd0);
                scalar_alu_op = 5'h00; // ADD PC + imm
            end

            // 4. Jumps (JAL, JALR)
            7'b1101111, 7'b1100111: begin
                is_jump      = 1'b1;
                reg_write_en = (rd_addr != 5'd0);
            end

            // 5. Branches (BEQ, BNE, BLT, BGE, BLTU, BGEU)
            7'b1100011: begin
                is_branch    = 1'b1;
            end

            // 6. Loads & Stores (LB, LH, LW, LBU, LHU, SB, SH, SW)
            7'b0000011: begin // LOAD
                is_load      = 1'b1;
                reg_write_en = (rd_addr != 5'd0);
            end
            7'b0100011: begin // STORE
                is_store     = 1'b1;
            end

            // 7. CSR / System (CSRRW, CSRRS, CSRRC)
            7'b1110011: begin
                is_csr       = 1'b1;
                reg_write_en = (rd_addr != 5'd0);
            end

            // 8. Custom-0 (0x0B): Neural / Tensor Operations
            OPCODE_CUSTOM_0: begin
                is_neural_op = 1'b1;
                case (funct3)
                    FUNCT3_TENS_CFG:     neural_op = 4'h0;
                    FUNCT3_TENS_LAUNCH:  neural_op = 4'h1;
                    FUNCT3_TENS_WAIT:    neural_op = 4'h2;
                    FUNCT3_TENS_ACT:     neural_op = 4'h3;
                    FUNCT3_TENS_SOFTMAX: neural_op = 4'h4;
                    FUNCT3_TENS_NORM:    neural_op = 4'h5;
                    default: illegal_instruction = 1'b1;
                endcase
                reg_write_en = (rd_addr != 5'd0) && (funct3 == FUNCT3_TENS_WAIT);
            end

            // 9. Custom-1 (0x2B): SIMD (funct7[6]=0) + Agent/Sync/Fence (funct7[6]=1)
            OPCODE_CUSTOM_1: begin
                if (funct7[6] == 1'b0) begin
                    // Partition A: 256-bit SIMD Vector Operations
                    is_vector_op = 1'b1;
                    vec_write_en = 1'b1;
                    vector_dtype = funct7[2:1]; // 00=INT8, 01=FP16, 10=INT32
                    vector_op    = {funct7[5], funct3};
                end else begin
                    // Partition B: Agentic, Synchronization & Fence Operations
                    case (funct3)
                        FUNCT3_WARP_YIELD:   is_yield      = 1'b1;
                        FUNCT3_BARRIER:      is_barrier    = 1'b1;
                        FUNCT3_AGENT_DAG:    begin is_agentic_op = 1'b1; agentic_op = 4'h1; end
                        FUNCT3_AGENT_KV:     begin is_agentic_op = 1'b1; agentic_op = 4'h4; reg_write_en = (rd_addr != 5'd0); end
                        FUNCT3_AGENT_ROUTER: begin is_agentic_op = 1'b1; agentic_op = 4'h7; end
                        FUNCT3_AI_FENCE:     is_fence      = 1'b1;
                        default: illegal_instruction = 1'b1;
                    endcase
                end
            end

            default: begin
                illegal_instruction = 1'b1;
            end
        endcase
    end

endmodule
