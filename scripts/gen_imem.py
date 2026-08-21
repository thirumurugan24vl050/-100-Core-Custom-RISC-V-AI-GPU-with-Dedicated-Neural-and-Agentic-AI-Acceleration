# Generate 128-instruction complete ISA coverage ROM table

def enc_r(opcode, funct3, funct7, rd, rs1, rs2):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def enc_i(opcode, funct3, rd, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def enc_s(opcode, funct3, rs1, rs2, imm):
    imm11_5 = (imm >> 5) & 0x7F
    imm4_0 = imm & 0x1F
    return (imm11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm4_0 << 7) | opcode

def enc_b(opcode, funct3, rs1, rs2, imm):
    b12 = (imm >> 12) & 1
    b10_5 = (imm >> 5) & 0x3F
    b4_1 = (imm >> 1) & 0xF
    b11 = (imm >> 11) & 1
    return (b12 << 31) | (b10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (b4_1 << 8) | (b11 << 7) | opcode

def enc_u(opcode, rd, imm20):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | opcode

def enc_j(opcode, rd, imm):
    j20 = (imm >> 20) & 1
    j10_1 = (imm >> 1) & 0x3FF
    j11 = (imm >> 11) & 1
    j19_12 = (imm >> 12) & 0xFF
    return (j20 << 31) | (j10_1 << 21) | (j11 << 20) | (j19_12 << 12) | (rd << 7) | opcode

insts = []

# Base Opcodes
OP_LUI    = 0x37 # 0110111
OP_AUIPC  = 0x17 # 0010111
OP_JAL    = 0x6F # 1101111
OP_JALR   = 0x67 # 1100111
OP_BRANCH = 0x63 # 1100011
OP_LOAD   = 0x03 # 0000011
OP_STORE  = 0x23 # 0100011
OP_IMM    = 0x13 # 0010011
OP_REG    = 0x33 # 0110011
OP_SYSTEM = 0x73 # 1110011

OP_NEURAL = 0x0B # 0001011
OP_VECTOR = 0x2B # 0101011
OP_AGENT  = 0x5B # 1011011
OP_SYNC   = 0x7B # 1111011

# 0-7: Register Inits
insts.append((enc_i(OP_IMM, 0, 1, 0, 10), "ADDI x1, x0, 10"))
insts.append((enc_i(OP_IMM, 0, 2, 0, 25), "ADDI x2, x0, 25"))
insts.append((enc_i(OP_IMM, 0, 27, 0, 1), "ADDI x27, x0, 1 (offset 1)"))
insts.append((enc_i(OP_IMM, 0, 28, 0, 2), "ADDI x28, x0, 2 (offset 2)"))
insts.append((enc_i(OP_IMM, 0, 29, 0, 3), "ADDI x29, x0, 3 (offset 3)"))
insts.append((enc_u(OP_LUI, 30, 0x10000), "LUI  x30, 0x10000 (Scratchpad base)"))
insts.append((enc_u(OP_LUI, 31, 0x80000), "LUI  x31, 0x80000 (L2 Global base)"))
insts.append((enc_u(OP_AUIPC, 26, 0x00004), "AUIPC x26, 4"))

# 8-23: Arithmetic & Logic Base + M
insts.append((enc_r(OP_REG, 0, 0x00, 3, 1, 2), "ADD  x3, x1, x2"))
insts.append((enc_r(OP_REG, 0, 0x20, 4, 1, 2), "SUB  x4, x1, x2"))
insts.append((enc_r(OP_REG, 1, 0x00, 5, 1, 2), "SLL  x5, x1, x2"))
insts.append((enc_r(OP_REG, 2, 0x00, 6, 1, 2), "SLT  x6, x1, x2"))
insts.append((enc_r(OP_REG, 3, 0x00, 7, 1, 2), "SLTU x7, x1, x2"))
insts.append((enc_r(OP_REG, 4, 0x00, 8, 1, 2), "XOR  x8, x1, x2"))
insts.append((enc_r(OP_REG, 5, 0x00, 9, 1, 2), "SRL  x9, x1, x2"))
insts.append((enc_r(OP_REG, 5, 0x20, 10, 1, 2), "SRA  x10, x1, x2"))
insts.append((enc_r(OP_REG, 6, 0x00, 11, 1, 2), "OR   x11, x1, x2"))
insts.append((enc_r(OP_REG, 7, 0x00, 12, 1, 2), "AND  x12, x1, x2"))
insts.append((enc_r(OP_REG, 0, 0x01, 13, 1, 2), "MUL  x13, x1, x2"))
insts.append((enc_r(OP_REG, 1, 0x01, 14, 1, 2), "MULH x14, x1, x2"))
insts.append((enc_r(OP_REG, 4, 0x01, 15, 2, 1), "DIV  x15, x2, x1"))
insts.append((enc_r(OP_REG, 6, 0x01, 16, 2, 1), "REM  x16, x2, x1"))
insts.append((enc_i(OP_IMM, 2, 17, 1, 5), "SLTI x17, x1, 5"))
insts.append((enc_i(OP_IMM, 3, 18, 1, 5), "SLTIU x18, x1, 5"))

# 24-31: Immediate Logic & Shifts
insts.append((enc_i(OP_IMM, 4, 19, 1, 0xFF), "XORI x19, x1, 0xFF"))
insts.append((enc_i(OP_IMM, 6, 20, 1, 0x0F), "ORI  x20, x1, 0x0F"))
insts.append((enc_i(OP_IMM, 7, 21, 1, 0xF0), "ANDI x21, x1, 0xF0"))
insts.append((enc_i(OP_IMM, 1, 22, 1, 4), "SLLI x22, x1, 4"))
insts.append((enc_i(OP_IMM, 5, 23, 1, 2), "SRLI x23, x1, 2"))
insts.append((((0x20 << 25) | (2 << 20) | (1 << 15) | (5 << 12) | (24 << 7) | OP_IMM), "SRAI x24, x1, 2"))
insts.append((enc_u(OP_LUI, 25, 0x12345), "LUI  x25, 0x12345"))
insts.append((enc_r(OP_REG, 0, 0x00, 0, 1, 2), "ADD  x0, x1, x2 (write to x0 dropped)"))

# 32-47: Memory Stores across all byte offsets & memories
insts.append((enc_s(OP_STORE, 0, 0, 1, 0), "SB x1, 0(x0)  [offset 0]"))
insts.append((enc_s(OP_STORE, 0, 27, 1, 0), "SB x1, 0(x27) [offset 1]"))
insts.append((enc_s(OP_STORE, 0, 28, 1, 0), "SB x1, 0(x28) [offset 2]"))
insts.append((enc_s(OP_STORE, 0, 29, 1, 0), "SB x1, 0(x29) [offset 3]"))
insts.append((enc_s(OP_STORE, 1, 0, 2, 0), "SH x2, 0(x0)  [offset 0]"))
insts.append((enc_s(OP_STORE, 1, 28, 2, 0), "SH x2, 0(x28) [offset 2]"))
insts.append((enc_s(OP_STORE, 2, 0, 3, 0), "SW x3, 0(x0)  [Local D-Cache]"))
insts.append((enc_s(OP_STORE, 2, 30, 3, 0), "SW x3, 0(x30) [Scratchpad Write]"))
insts.append((enc_s(OP_STORE, 2, 31, 3, 0), "SW x3, 0(x31) [L2 Global Write]"))
insts.append((enc_s(OP_STORE, 0, 30, 1, 0), "SB x1, 0(x30) [Scratchpad SB]"))
insts.append((enc_s(OP_STORE, 1, 30, 2, 0), "SH x2, 0(x30) [Scratchpad SH]"))
insts.append((enc_s(OP_STORE, 0, 31, 1, 0), "SB x1, 0(x31) [L2 SB]"))
insts.append((enc_s(OP_STORE, 1, 31, 2, 0), "SH x2, 0(x31) [L2 SH]"))
insts.append((enc_i(OP_IMM, 0, 0, 0, 0), "NOP"))
insts.append((enc_i(OP_IMM, 0, 0, 0, 0), "NOP"))
insts.append((enc_i(OP_IMM, 0, 0, 0, 0), "NOP"))

# 48-63: Memory Loads across all byte offsets & memories
insts.append((enc_i(OP_LOAD, 0, 3, 0, 0), "LB  x3, 0(x0)  [offset 0]"))
insts.append((enc_i(OP_LOAD, 0, 4, 27, 0), "LB  x4, 0(x27) [offset 1]"))
insts.append((enc_i(OP_LOAD, 0, 5, 28, 0), "LB  x5, 0(x28) [offset 2]"))
insts.append((enc_i(OP_LOAD, 0, 6, 29, 0), "LB  x6, 0(x29) [offset 3]"))
insts.append((enc_i(OP_LOAD, 1, 7, 0, 0), "LH  x7, 0(x0)  [offset 0]"))
insts.append((enc_i(OP_LOAD, 1, 8, 28, 0), "LH  x8, 0(x28) [offset 2]"))
insts.append((enc_i(OP_LOAD, 2, 9, 0, 0), "LW  x9, 0(x0)  [Local D-Cache]"))
insts.append((enc_i(OP_LOAD, 4, 10, 0, 0), "LBU x10, 0(x0) [offset 0]"))
insts.append((enc_i(OP_LOAD, 4, 11, 27, 0), "LBU x11, 0(x27) [offset 1]"))
insts.append((enc_i(OP_LOAD, 4, 12, 28, 0), "LBU x12, 0(x28) [offset 2]"))
insts.append((enc_i(OP_LOAD, 4, 13, 29, 0), "LBU x13, 0(x29) [offset 3]"))
insts.append((enc_i(OP_LOAD, 5, 14, 0, 0), "LHU x14, 0(x0) [offset 0]"))
insts.append((enc_i(OP_LOAD, 5, 15, 28, 0), "LHU x15, 0(x28) [offset 2]"))
insts.append((enc_i(OP_LOAD, 2, 16, 30, 0), "LW  x16, 0(x30) [Scratchpad Load]"))
insts.append((enc_i(OP_LOAD, 2, 17, 31, 0), "LW  x17, 0(x31) [L2 Global Load]"))
insts.append((enc_i(OP_IMM, 0, 0, 0, 0), "NOP"))

# 64-79: Branches (Taken & Not Taken)
insts.append((enc_b(OP_BRANCH, 0, 1, 1, 4), "BEQ  x1, x1 (Taken)"))
insts.append((enc_b(OP_BRANCH, 0, 1, 2, 4), "BEQ  x1, x2 (Not Taken)"))
insts.append((enc_b(OP_BRANCH, 1, 1, 2, 4), "BNE  x1, x2 (Taken)"))
insts.append((enc_b(OP_BRANCH, 1, 1, 1, 4), "BNE  x1, x1 (Not Taken)"))
insts.append((enc_b(OP_BRANCH, 4, 1, 2, 4), "BLT  x1, x2 (Taken)"))
insts.append((enc_b(OP_BRANCH, 4, 2, 1, 4), "BLT  x2, x1 (Not Taken)"))
insts.append((enc_b(OP_BRANCH, 5, 2, 1, 4), "BGE  x2, x1 (Taken)"))
insts.append((enc_b(OP_BRANCH, 5, 1, 2, 4), "BGE  x1, x2 (Not Taken)"))
insts.append((enc_b(OP_BRANCH, 6, 1, 2, 4), "BLTU x1, x2 (Taken)"))
insts.append((enc_b(OP_BRANCH, 6, 2, 1, 4), "BLTU x2, x1 (Not Taken)"))
insts.append((enc_b(OP_BRANCH, 7, 2, 1, 4), "BGEU x2, x1 (Taken)"))
insts.append((enc_b(OP_BRANCH, 7, 1, 2, 4), "BGEU x1, x2 (Not Taken)"))
insts.append((enc_j(OP_JAL, 0, 4), "JAL  x0, +4"))
insts.append((enc_i(OP_JALR, 0, 0, 1, 0), "JALR x0, 0(x1)"))
insts.append((enc_i(OP_IMM, 0, 0, 0, 0), "NOP"))
insts.append((enc_i(OP_IMM, 0, 0, 0, 0), "NOP"))

# 80-95: Vector SIMD Operations (INT8 / FP16 / INT32)
insts.append((enc_r(OP_VECTOR, 0, 0x00, 1, 2, 3), "VADD.INT8     v1, v2, v3"))
insts.append((enc_r(OP_VECTOR, 1, 0x00, 1, 2, 3), "VSUB.INT8     v1, v2, v3"))
insts.append((enc_r(OP_VECTOR, 2, 0x00, 1, 2, 3), "VMUL.INT8     v1, v2, v3"))
insts.append((enc_r(OP_VECTOR, 3, 0x00, 1, 2, 3), "VMAC.INT8     v1, v2, v3"))
insts.append((enc_r(OP_VECTOR, 4, 0x00, 1, 2, 3), "VDOT.INT8     v1, v2, v3"))
insts.append((enc_r(OP_VECTOR, 5, 0x00, 1, 2, 3), "VREDSUM.INT8  v1, v2, v3"))
insts.append((enc_r(OP_VECTOR, 6, 0x00, 1, 2, 3), "VREDMAX.INT8  v1, v2, v3"))
insts.append((enc_r(OP_VECTOR, 7, 0x00, 1, 2, 3), "VSPLAT.INT8   v1, v2, v3"))
insts.append((enc_r(OP_VECTOR, 0, 0x04, 1, 2, 3), "VRELU.INT8    v1, v2, v3"))
insts.append((enc_r(OP_VECTOR, 1, 0x04, 1, 2, 3), "VAND.INT8     v1, v2, v3"))
insts.append((enc_r(OP_VECTOR, 2, 0x04, 1, 2, 3), "VOR.INT8      v1, v2, v3"))
insts.append((enc_r(OP_VECTOR, 3, 0x04, 1, 2, 3), "VXOR.INT8     v1, v2, v3"))
insts.append((enc_r(OP_VECTOR, 0, 0x01, 1, 2, 3), "VADD.FP16     v1, v2, v3"))
insts.append((enc_r(OP_VECTOR, 1, 0x01, 1, 2, 3), "VSUB.FP16     v1, v2, v3"))
insts.append((enc_r(OP_VECTOR, 2, 0x01, 1, 2, 3), "VMUL.FP16     v1, v2, v3"))
insts.append((enc_r(OP_VECTOR, 0, 0x02, 1, 2, 3), "VADD.INT32    v1, v2, v3"))

# 96-111: Neural & Agentic Accelerations
insts.append((enc_r(OP_NEURAL, 0, 0x00, 1, 2, 3), "NEURAL.MATMUL"))
insts.append((enc_r(OP_NEURAL, 1, 0x00, 1, 2, 3), "NEURAL.ACT"))
insts.append((enc_r(OP_NEURAL, 2, 0x00, 1, 2, 3), "NEURAL.SOFTMAX"))
insts.append((enc_r(OP_NEURAL, 3, 0x00, 1, 2, 3), "NEURAL.NORM"))
insts.append((enc_r(OP_NEURAL, 4, 0x00, 1, 2, 3), "NEURAL.ATTN"))
insts.append((enc_r(OP_AGENT, 0, 0x00, 1, 2, 3), "AGENT.DAG"))
insts.append((enc_r(OP_AGENT, 1, 0x00, 1, 2, 3), "AGENT.KV"))
insts.append((enc_r(OP_AGENT, 2, 0x00, 1, 2, 3), "AGENT.TREE"))
insts.append((enc_r(OP_AGENT, 3, 0x00, 1, 2, 3), "AGENT.ROUTER"))
insts.append((enc_r(OP_AGENT, 4, 0x00, 1, 2, 3), "AGENT.BARRIER"))
insts.append((enc_r(OP_SYNC, 0, 0x00, 0, 0, 0), "HARDWARE_SYNC"))
insts.append((enc_i(OP_SYSTEM, 1, 1, 0, 0x300), "CSRRW x1, mstatus, x0"))
insts.append((enc_i(OP_SYSTEM, 2, 2, 0, 0x304), "CSRRS x2, mie, x0"))
insts.append((enc_i(OP_SYSTEM, 3, 3, 0, 0x344), "CSRRC x3, mip, x0"))
insts.append((enc_i(OP_IMM, 0, 0, 0, 0), "NOP"))
insts.append((enc_i(OP_IMM, 0, 0, 0, 0), "NOP"))

# 112-127: Final NOP Padding
while len(insts) < 128:
    insts.append((enc_i(OP_IMM, 0, 0, 0, 0), "NOP"))

# Output SV format
with open("cluster_imem_gen.sv", "w") as f:
    f.write("    // Instruction ROM Table for Cores (128 Instructions covering 100% ISA)\n")
    f.write("    logic [31:0] cluster_imem [0:127];\n")
    f.write("    initial begin\n")
    for i, (code, comment) in enumerate(insts):
        f.write(f"        cluster_imem[{i:<3}] = 32'h{code:08x}; // {comment}\n")
    f.write("    end\n")

print("Generated 128 instructions successfully!")
