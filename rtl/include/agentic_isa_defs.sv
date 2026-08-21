//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: agentic_isa_defs.sv
// Description: ISA instruction formats, decoder bitfields, and CSR definitions.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`ifndef AGENTIC_ISA_DEFS_SV
`define AGENTIC_ISA_DEFS_SV

// Control and Status Register (CSR) Addresses for Neural & Agentic Core
`define CSR_NEURAL_STATUS      12'h800 // Neural Engine Status (Busy, Done, Error)
`define CSR_NEURAL_CONFIG      12'h801 // Precision mode (INT8, FP16, BF16) & Array config
`define CSR_NEURAL_SRC_A       12'h802 // Matrix A Pointer in Scratchpad
`define CSR_NEURAL_SRC_B       12'h803 // Matrix B Pointer in Scratchpad
`define CSR_NEURAL_DST_C       12'h804 // Matrix C Destination Pointer
`define CSR_NEURAL_DIM_M       12'h805 // Matrix M dimension
`define CSR_NEURAL_DIM_K       12'h806 // Matrix K dimension
`define CSR_NEURAL_DIM_N       12'h807 // Matrix N dimension

`define CSR_AGENT_NODE_ID      12'h810 // Current active Agent Node ID
`define CSR_AGENT_GRAPH_STATE  12'h811 // Active DAG status and pending count
`define CSR_AGENT_KV_ROOT      12'h812 // Base address of Paged KV Page Table
`define CSR_AGENT_SPEC_TEMP    12'h813 // Speculative temperature threshold register
`define CSR_AGENT_BARRIER_REG  12'h814 // Cluster barrier register mask

// Custom Instruction Bitfield Extractions
`define GET_OPCODE(inst)    (inst[6:0])
`define GET_RD(inst)        (inst[11:7])
`define GET_FUNCT3(inst)    (inst[14:12])
`define GET_RS1(inst)       (inst[19:15])
`define GET_RS2(inst)       (inst[24:20])
`define GET_FUNCT7(inst)    (inst[31:25])
`define GET_IMM_I(inst)     ({{20{inst[31]}}, inst[31:20]})
`define GET_IMM_S(inst)     ({{20{inst[31]}}, inst[31:25], inst[11:7]})
`define GET_IMM_B(inst)     ({{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0})
`define GET_IMM_U(inst)     ({inst[31:12], 12'h000})
`define GET_IMM_J(inst)     ({{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0})

`endif // AGENTIC_ISA_DEFS_SV
