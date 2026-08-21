//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: riscv_ai_gpu_pkg.sv
// Description: Global package containing system parameters, data types, 
//              custom instruction opcodes, NoC flit formats, and agent structs.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`include "agentic_isa_defs.sv"

package riscv_ai_gpu_pkg;

    //-------------------------------------------------------------------------
    // 1. SYSTEM TOPOLOGY CONSTANTS
    //-------------------------------------------------------------------------
    localparam int TOTAL_CORES        = 100;
    localparam int NUM_CLUSTERS       = 10;
    localparam int CORES_PER_CLUSTER  = 10;
    localparam int NOC_ROWS           = 10;
    localparam int NOC_COLS           = 10;
    localparam int NOC_NUM_ROUTERS    = 100;

    //-------------------------------------------------------------------------
    // 2. CORE & DATA PATH CONSTANTS
    //-------------------------------------------------------------------------
    localparam int XLEN               = 32;       // Scalar Datapath Width (RV32)
    localparam int VLEN               = 256;      // Vector Datapath Width (256-bit SIMD)
    localparam int NUM_WARPS          = 4;        // Hardware Warps per Core
    localparam int NUM_SCALAR_REGS    = 32;       // 32 architectural scalar registers
    localparam int NUM_VECTOR_REGS    = 32;       // 32 architectural vector registers
    localparam int ICACHE_SIZE_KB     = 4;        // 4KB L1 Instruction Cache
    localparam int DCACHE_SIZE_KB     = 4;        // 4KB L1 Data Cache
    localparam int CLUSTER_SRAM_KB    = 64;       // 64KB Cluster Shared SRAM

    //-------------------------------------------------------------------------
    // 3. NEURAL ACCELERATOR CONSTANTS
    //-------------------------------------------------------------------------
    localparam int SYSTOLIC_DIM       = 8;        // 8x8 Systolic Processing Array
    localparam int ACTIVATION_WIDTH   = 8;        // INT8 / FP8 activation width
    localparam int WEIGHT_WIDTH       = 8;        // INT8 / FP8 weight width
    localparam int ACCUM_WIDTH        = 32;       // 32-bit accumulation width
    localparam int FP16_WIDTH         = 16;       // FP16 / BF16 arithmetic width

    // Neural Operation Enums
    typedef enum logic [3:0] {
        NEURAL_OP_NOP         = 4'h0,
        NEURAL_OP_MATMUL      = 4'h1,
        NEURAL_OP_CONV2D      = 4'h2,
        NEURAL_OP_RELU        = 4'h3,
        NEURAL_OP_GELU        = 4'h4,
        NEURAL_OP_SIGMOID     = 4'h5,
        NEURAL_OP_SOFTMAX     = 4'h6,
        NEURAL_OP_LAYERNORM   = 4'h7,
        NEURAL_OP_RMSNORM     = 4'h8,
        NEURAL_OP_ATTENTION   = 4'h9,
        NEURAL_OP_SPARSE_MASK = 4'hA
    } neural_op_e;

    //-------------------------------------------------------------------------
    // 4. AGENTIC AI ACCELERATOR CONSTANTS
    //-------------------------------------------------------------------------
    localparam int MAX_DAG_NODES      = 64;       // Max concurrent active Agent DAG nodes
    localparam int DAG_NODE_ID_WIDTH  = 6;        // 6-bit node ID (0..63)
    localparam int KV_PAGE_SIZE_BYTES = 4096;     // 4KB Page size for Paged KV-Cache
    localparam int KV_MAX_PAGES       = 1024;     // 1024 Physical KV Pages (4MB on-chip / managed)
    localparam int KV_PAGE_ID_WIDTH   = 10;       // 10-bit physical page ID
    localparam int AGENT_PRIO_LEVELS  = 8;        // 8 priority levels (0..7)
    localparam int MCTS_MAX_DEPTH     = 16;       // Max depth for hardware tree search

    // Agentic Operation Enums
    typedef enum logic [3:0] {
        AGENT_OP_NOP          = 4'h0,
        AGENT_OP_DAG_INSERT   = 4'h1,
        AGENT_OP_DAG_DEPEND   = 4'h2,
        AGENT_OP_DAG_FIRE     = 4'h3,
        AGENT_OP_KV_ALLOC     = 4'h4,
        AGENT_OP_KV_FREE      = 4'h5,
        AGENT_OP_KV_LOOKUP    = 4'h6,
        AGENT_OP_TREE_EVAL    = 4'h7,
        AGENT_OP_TOKEN_ROUTE  = 4'h8,
        AGENT_OP_BARRIER_SYNC = 4'h9
    } agentic_op_e;

    // Agent DAG Node Structure
    typedef struct packed {
        logic [DAG_NODE_ID_WIDTH-1:0]  node_id;
        logic [2:0]                    task_prio;
        logic [MAX_DAG_NODES-1:0]      dependency_mask; // Bitmask of prerequisite tasks
        logic [7:0]                    cluster_target;  // Target cluster or 8'hFF for dynamic
        logic [31:0]                   instruction_ptr; // PC start address
        logic [31:0]                   context_ptr;     // Pointer to agent context state
        logic                          valid;
        logic                          ready;
        logic                          running;
        logic                          completed;
    } agent_dag_node_t;

    // Paged KV-Cache Page Table Entry Structure
    typedef struct packed {
        logic [KV_PAGE_ID_WIDTH-1:0]   physical_page;
        logic                          valid;
        logic                          dirty;
        logic [1:0]                    reference_count; // For multi-agent shared prefix cache
        logic [15:0]                   token_count;     // Tokens stored in this page (up to 4096)
    } paged_kv_entry_t;

    //-------------------------------------------------------------------------
    // 5. NETWORK-ON-CHIP (NoC) PACKET & FLIT STRUCTURES
    //-------------------------------------------------------------------------
    localparam int NOC_FLIT_WIDTH     = 128;      // 128-bit payload per flit
    localparam int NOC_VC_COUNT       = 3;        // VC0: Req, VC1: Resp, VC2: Agentic Sync

    // Flit Type Enum
    typedef enum logic [1:0] {
        FLIT_HEAD   = 2'b00,
        FLIT_BODY   = 2'b01,
        FLIT_TAIL   = 2'b10,
        FLIT_SINGLE = 2'b11
    } flit_type_e;

    // Virtual Channel Enum
    typedef enum logic [1:0] {
        VC_REQ   = 2'b00,
        VC_RESP  = 2'b01,
        VC_AGENT = 2'b10
    } noc_vc_e;

    // NoC Flit Packet Structure
    typedef struct packed {
        flit_type_e                    flit_type;
        noc_vc_e                       vc_id;
        logic [3:0]                    src_x;
        logic [3:0]                    src_y;
        logic [3:0]                    dst_x;
        logic [3:0]                    dst_y;
        logic [7:0]                    msg_type; // Read, Write, Atomic, Neural Sync, Agent Msg
        logic [NOC_FLIT_WIDTH-1:0]     payload;
    } noc_flit_t;

    //-------------------------------------------------------------------------
    // 6. CUSTOM RISC-V EXTENSION OPCODES
    //-------------------------------------------------------------------------
    // Standard R-Type / Custom-0 / Custom-1 / Custom-2 / Custom-3 Opcodes
    localparam logic [6:0] OPCODE_CUSTOM_NEURAL  = 7'b0001011; // custom-0 (0x0B)
    localparam logic [6:0] OPCODE_CUSTOM_VECTOR  = 7'b0101011; // custom-1 (0x2B)
    localparam logic [6:0] OPCODE_CUSTOM_AGENTIC = 7'b1011011; // custom-2 (0x5B)
    localparam logic [6:0] OPCODE_CUSTOM_SYNC    = 7'b1111011; // custom-3 (0x7B)

    // Neural Sub-Funct3 / Funct7 Definitions
    localparam logic [2:0] FUNCT3_NEURAL_MATMUL  = 3'b000;
    localparam logic [2:0] FUNCT3_NEURAL_ACT     = 3'b001;
    localparam logic [2:0] FUNCT3_NEURAL_SOFTMAX = 3'b010;
    localparam logic [2:0] FUNCT3_NEURAL_NORM    = 3'b011;
    localparam logic [2:0] FUNCT3_NEURAL_ATTN    = 3'b100;

    // Agentic Sub-Funct3 Definitions
    localparam logic [2:0] FUNCT3_AGENT_DAG      = 3'b000;
    localparam logic [2:0] FUNCT3_AGENT_KV       = 3'b001;
    localparam logic [2:0] FUNCT3_AGENT_TREE     = 3'b010;
    localparam logic [2:0] FUNCT3_AGENT_ROUTER   = 3'b011;
    localparam logic [2:0] FUNCT3_AGENT_BARRIER  = 3'b100;

endpackage : riscv_ai_gpu_pkg
