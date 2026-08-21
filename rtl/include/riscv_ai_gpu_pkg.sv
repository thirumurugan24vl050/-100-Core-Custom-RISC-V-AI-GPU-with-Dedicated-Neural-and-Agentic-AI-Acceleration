//=============================================================================
// Project: 100-Core Custom RISC-V SIMT AI GPU with Neural & Agentic Acceleration
// File: riscv_ai_gpu_pkg.sv
// Description: Global package containing system parameters, data types, 
//              custom instruction opcodes, NoC flit formats, and agent structs.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`include "agentic_isa_defs.sv"

package riscv_ai_gpu_pkg;

    //-------------------------------------------------------------------------
    // 1. SYSTEM TOPOLOGY & GATEWAY CONSTANTS
    //-------------------------------------------------------------------------
    localparam int TOTAL_CORES            = 100;
    localparam int NUM_CLUSTERS           = 10;
    localparam int CORES_PER_CLUSTER      = 10;
    localparam int NOC_ROWS               = 10;
    localparam int NOC_COLS               = 10;
    localparam int NOC_NUM_ROUTERS        = 100;

    // Deterministic Global Gateway NoC Coordinates
    localparam int GLOBAL_AGENT_NODE_X    = 0;
    localparam int GLOBAL_AGENT_NODE_Y    = 0;
    localparam int GLOBAL_MEMORY_NODE_X   = 9;
    localparam int GLOBAL_MEMORY_NODE_Y   = 9;
    localparam int HOST_DMA_NODE_X        = 5;
    localparam int HOST_DMA_NODE_Y        = 0;

    //-------------------------------------------------------------------------
    // 2. CORE & DATA PATH CONSTANTS
    //-------------------------------------------------------------------------
    localparam int XLEN                   = 32;       // Scalar Datapath Width (RV32)
    localparam int PLEN                   = 64;       // 64-bit System Physical Address Width
    localparam int VLEN                   = 256;      // Vector Datapath Width (256-bit SIMD)
    localparam int NUM_WARPS              = 4;        // Hardware Warps per Core
    localparam int WARP_LANES             = 32;       // 32 Logical Lanes per Warp
    localparam int RECONV_STACK_DEPTH     = 8;        // 8-entry branch reconvergence stack
    localparam int NUM_SCALAR_REGS        = 32;       // 32 architectural scalar registers
    localparam int NUM_VECTOR_REGS        = 32;       // 32 architectural vector registers
    localparam int ICACHE_SIZE_KB         = 4;        // 4KB L1 Instruction Cache
    localparam int CLUSTER_SRAM_KB        = 64;       // 64KB Cluster Shared SRAM
    localparam int CLUSTER_SRAM_BANKS     = 8;        // 8 Banks x 8KB (1R/1W per bank)

    // Unambiguous Warp Architectural State Enum
    typedef enum logic [2:0] {
        WARP_READY        = 3'b000,
        WARP_RUNNING      = 3'b001,
        WARP_WAIT_MEM     = 3'b010,
        WARP_WAIT_NMU     = 3'b011,
        WARP_WAIT_BARRIER = 3'b100,
        WARP_WAIT_AGENT   = 3'b101,
        WARP_DONE         = 3'b110
    } warp_state_e;

    // Reconvergence Stack Entry
    typedef struct packed {
        logic [31:0]                   reconv_pc;
        logic [WARP_LANES-1:0]         reconv_mask;
    } reconv_entry_t;

    //-------------------------------------------------------------------------
    // 3. NEURAL ACCELERATOR CONSTANTS
    //-------------------------------------------------------------------------
    localparam int SYSTOLIC_DIM           = 8;        // 8x8 Systolic Processing Array
    localparam int ACTIVATION_WIDTH       = 8;        // INT8 / FP8 activation width
    localparam int WEIGHT_WIDTH           = 8;        // INT8 / FP8 weight width
    localparam int ACCUM_WIDTH            = 32;       // 32-bit accumulation width
    localparam int FP16_WIDTH             = 16;       // FP16 / BF16 arithmetic width
    localparam int NMU_CMD_FIFO_DEPTH     = 8;        // 8-entry NMU command queue

    // Decoupled Tensor CSR Descriptors
    typedef struct packed {
        logic [63:0]                   src_a_addr;
        logic [63:0]                   src_b_addr;
        logic [63:0]                   dst_c_addr;
        logic [15:0]                   dim_m;
        logic [15:0]                   dim_n;
        logic [15:0]                   dim_k;
        logic [3:0]                    data_type;
        logic [3:0]                    tile_size;
        logic [15:0]                   stride_a;
        logic [15:0]                   stride_b;
        logic [15:0]                   stride_c;
    } tens_descriptor_t;

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
        logic [63:0]                   instruction_ptr; // 64-bit PC start address
        logic [63:0]                   context_ptr;     // 64-bit Pointer to agent context state
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
    // 5. 512-BIT SCATTER-GATHER DMA DESCRIPTOR STRUCTURE
    //-------------------------------------------------------------------------
    typedef struct packed {
        logic [63:0]                   src_addr;        // 64-bit source physical address
        logic [63:0]                   dst_addr;        // 64-bit destination physical address
        logic [31:0]                   length;          // Transfer length in bytes
        logic [31:0]                   stride;          // Source/destination stride
        logic [7:0]                    burst_len;       // AXI burst length (1..256 beats)
        logic [7:0]                    dest_cluster;    // Target cluster ID (0..9) or broadcast
        logic                          direction;       // 1 = DRAM -> SPAD, 0 = SPAD -> DRAM
        logic                          interrupt_en;    // Assert interrupt on completion
        logic [63:0]                   next_desc_ptr;   // 64-bit pointer to next descriptor
        logic [31:0]                   flags;           // Control flags and status
    } dma_descriptor_t;

    //-------------------------------------------------------------------------
    // 6. NETWORK-ON-CHIP (NoC) 160-BIT FLIT STRUCTURES
    //-------------------------------------------------------------------------
    localparam int NOC_HEADER_WIDTH   = 32;       // 32-bit header width
    localparam int NOC_PAYLOAD_WIDTH  = 128;      // 128-bit payload width
    localparam int NOC_TOTAL_FLIT     = 160;      // 160-bit total flit width
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

    // Message Type Enums
    typedef enum logic [7:0] {
        MSG_MEM_REQ      = 8'h01,
        MSG_MEM_RESP     = 8'h02,
        MSG_AGENT_TASK   = 8'h03,
        MSG_AGENT_EVENT  = 8'h04,
        MSG_BARRIER_SYNC = 8'h05,
        MSG_TOKEN_ROUTE  = 8'h06
    } noc_msg_type_e;

    // 128-bit Memory Request Payload Structure (64-bit Physical Address, 128 bits exact)
    typedef struct packed {
        logic [63:0]                   addr;          // [127:64] (64-bit address)
        logic [15:0]                   transaction_id;// [63:48]
        logic [15:0]                   byte_enable;   // [47:32]
        logic [7:0]                    burst_len;     // [31:24]
        logic                          rw_flag;       // [23]
        logic [3:0]                    req_type;      // [22:19]
        logic [18:0]                   reserved;      // [18:0]
    } msg_mem_req_payload_t;

    // 128-bit Memory Response Payload Structure (Exactly 128 bits)
    typedef struct packed {
        logic [15:0]                   transaction_id;// [127:112]
        logic [15:0]                   status;        // [111:96]
        logic [63:0]                   read_data;     // [95:32]
        logic [31:0]                   reserved;      // [31:0]
    } msg_mem_resp_payload_t;

    // 160-bit Unified NoC Flit Packet Structure (Flat packed for direct member access)
    typedef struct packed {
        flit_type_e                    flit_type;     // [159:158] (2 bits)
        noc_vc_e                       vc_id;         // [157:156] (2 bits)
        logic [3:0]                    src_x;         // [155:152] (4 bits)
        logic [3:0]                    src_y;         // [151:148] (4 bits)
        logic [3:0]                    dst_x;         // [147:144] (4 bits)
        logic [3:0]                    dst_y;         // [143:140] (4 bits)
        logic [7:0]                    msg_type;      // [139:132] (8 bits)
        logic [3:0]                    flags;         // [131:128] (4 bits)
        logic [NOC_PAYLOAD_WIDTH-1:0]  payload;       // [127:0]   (128 bits)
    } noc_flit_t;

    //-------------------------------------------------------------------------
    // 7. CUSTOM RISC-V 2-OPCODE EXTENSION DEFINITIONS
    //-------------------------------------------------------------------------
    localparam logic [6:0] OPCODE_CUSTOM_0      = 7'b0001011; // CUSTOM-0 (0x0B) -> Tensor/Neural
    localparam logic [6:0] OPCODE_CUSTOM_1      = 7'b0101011; // CUSTOM-1 (0x2B) -> SIMT/Agent/Sync
    localparam logic [6:0] OPCODE_CUSTOM_NEURAL  = OPCODE_CUSTOM_0;
    localparam logic [6:0] OPCODE_CUSTOM_VECTOR  = OPCODE_CUSTOM_1;
    localparam logic [6:0] OPCODE_CUSTOM_AGENTIC = OPCODE_CUSTOM_1;
    localparam logic [6:0] OPCODE_CUSTOM_SYNC    = OPCODE_CUSTOM_1;

    // Neural Sub-Funct3 Definitions (CUSTOM-0)
    localparam logic [2:0] FUNCT3_TENS_CFG       = 3'b000;
    localparam logic [2:0] FUNCT3_TENS_LAUNCH    = 3'b001;
    localparam logic [2:0] FUNCT3_TENS_WAIT      = 3'b010;
    localparam logic [2:0] FUNCT3_TENS_ACT       = 3'b011;
    localparam logic [2:0] FUNCT3_TENS_SOFTMAX   = 3'b100;
    localparam logic [2:0] FUNCT3_TENS_NORM      = 3'b101;

    // Compatibility aliases
    localparam logic [2:0] FUNCT3_NEURAL_MATMUL  = FUNCT3_TENS_LAUNCH;
    localparam logic [2:0] FUNCT3_NEURAL_ACT     = FUNCT3_TENS_ACT;
    localparam logic [2:0] FUNCT3_NEURAL_SOFTMAX = FUNCT3_TENS_SOFTMAX;
    localparam logic [2:0] FUNCT3_NEURAL_NORM    = FUNCT3_TENS_NORM;
    localparam logic [2:0] FUNCT3_NEURAL_ATTN    = 3'b110;

    // SIMT / Agentic / Sync Sub-Funct3 Definitions (CUSTOM-1)
    localparam logic [2:0] FUNCT3_WARP_YIELD     = 3'b000;
    localparam logic [2:0] FUNCT3_BARRIER        = 3'b001;
    localparam logic [2:0] FUNCT3_AGENT_DAG      = 3'b010;
    localparam logic [2:0] FUNCT3_AGENT_KV       = 3'b011;
    localparam logic [2:0] FUNCT3_AGENT_TREE     = 3'b100;
    localparam logic [2:0] FUNCT3_AGENT_ROUTER   = 3'b101;
    localparam logic [2:0] FUNCT3_AGENT_BARRIER  = FUNCT3_BARRIER;
    localparam logic [2:0] FUNCT3_AI_FENCE       = 3'b111;

endpackage : riscv_ai_gpu_pkg
