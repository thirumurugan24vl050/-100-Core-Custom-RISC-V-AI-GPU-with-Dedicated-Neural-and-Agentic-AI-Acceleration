//=============================================================================
// Project: 100-Core Custom RISC-V SIMT AI GPU with Neural & Agentic Acceleration
// File:    riscv_ai_gpu_pkg.sv
// Version: Implementation Baseline v1.0
// Description: Authoritative global package containing all frozen system
//              parameters, data types, ISA encodings, NoC flit formats,
//              DMA descriptor, and agent structures.
//              EVERY RTL module imports this package. No module may define
//              its own conflicting constants.
// Standard: IEEE 1800-2017 SystemVerilog (synthesizable subset only)
//=============================================================================

`include "agentic_isa_defs.sv"

package riscv_ai_gpu_pkg;

    //=========================================================================
    // 1. SYSTEM TOPOLOGY & GATEWAY CONSTANTS
    //=========================================================================
    localparam int TOTAL_CORES            = 100;
    localparam int NUM_CLUSTERS           = 10;
    localparam int CORES_PER_CLUSTER      = 10;
    localparam int NOC_ROWS               = 10;
    localparam int NOC_COLS               = 10;
    localparam int NOC_MESH_X             = 10;
    localparam int NOC_MESH_Y             = 10;
    localparam int NOC_NUM_ROUTERS        = 100;

    // Deterministic Global Gateway NoC Coordinates
    // (0,0) = Agentic Coprocessor Gateway
    // (9,9) = Memory Gateway (Global Buffer + External AXI)
    // (5,0) = Host DMA Gateway
    localparam int GLOBAL_AGENT_NODE_X    = 0;
    localparam int GLOBAL_AGENT_NODE_Y    = 0;
    localparam int GLOBAL_MEMORY_NODE_X   = 9;
    localparam int GLOBAL_MEMORY_NODE_Y   = 9;
    localparam int HOST_DMA_NODE_X        = 5;
    localparam int HOST_DMA_NODE_Y        = 0;

    //=========================================================================
    // 2. CORE & DATA PATH CONSTANTS
    //=========================================================================
    localparam int XLEN                   = 32;       // Scalar Datapath Width (RV32)
    localparam int PLEN                   = 64;       // 64-bit System Physical Address Width
    localparam int VLEN                   = 256;      // Vector Datapath Width (256-bit SIMD)
    localparam int FP16_WIDTH             = 16;       // FP16 arithmetic width (used by core SIMD vec_dtype=01)
    localparam int NUM_WARPS              = 4;        // Hardware Warps per Core
    localparam int WARP_LANES             = 32;       // 32 Logical Lanes per Warp
    localparam int RECONV_STACK_DEPTH     = 8;        // 8-entry branch reconvergence stack per warp
    localparam int NUM_SCALAR_REGS        = 32;       // 32 architectural scalar registers per warp context
    localparam int NUM_VECTOR_REGS        = 32;       // 32 architectural vector registers per warp context
    localparam int ICACHE_SIZE_KB         = 4;        // 4KB L1 Instruction Cache per core
    localparam int CLUSTER_SRAM_KB        = 64;       // 64KB Cluster Shared Scratchpad SRAM
    localparam int CLUSTER_SRAM_BANKS     = 8;        // 8 Banks x 8KB (1R/1W per bank)

    // Register File Sizing:
    //   4 independent architectural register contexts (one per warp),
    //   each containing 32 x 32-bit scalar registers.
    //   x0 is hardwired to zero in every warp context.
    //   Total storage: 4 x 32 x 32 = 4096 bits = 512 bytes.
    localparam int REGFILE_TOTAL_ENTRIES   = NUM_WARPS * NUM_SCALAR_REGS; // 128
    localparam int REGFILE_ADDR_WIDTH      = $clog2(REGFILE_TOTAL_ENTRIES); // 7

    //-------------------------------------------------------------------------
    // 2a. Warp Architectural State Enum (7 states, 3-bit encoding)
    //-------------------------------------------------------------------------
    typedef enum logic [2:0] {
        WARP_READY        = 3'b000,
        WARP_RUNNING      = 3'b001,
        WARP_WAIT_MEM     = 3'b010,
        WARP_WAIT_NMU     = 3'b011,
        WARP_WAIT_BARRIER = 3'b100,
        WARP_WAIT_AGENT   = 3'b101,
        WARP_DONE         = 3'b110
    } warp_state_e;

    //-------------------------------------------------------------------------
    // 2b. Reconvergence Stack Entry
    //-------------------------------------------------------------------------
    typedef struct packed {
        logic [31:0]                   reconv_pc;
        logic [WARP_LANES-1:0]         reconv_mask;
    } reconv_entry_t;

    //=========================================================================
    // 3. NEURAL ACCELERATOR CONSTANTS (V1: INT8 x INT8 -> INT32 only)
    //=========================================================================
    localparam int SYSTOLIC_DIM           = 8;        // 8x8 Systolic Processing Array
    localparam int ACTIVATION_WIDTH       = 8;        // INT8 activation width (V1)
    localparam int WEIGHT_WIDTH           = 8;        // INT8 weight width (V1)
    localparam int ACCUM_WIDTH            = 32;       // 32-bit accumulation width
    localparam int NMU_CMD_FIFO_DEPTH     = 8;        // 8-entry NMU command queue

    //-------------------------------------------------------------------------
    // 3a. Decoupled Tensor CSR Descriptor (for TENS_CFG/TENS_LAUNCH)
    //-------------------------------------------------------------------------
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

    //-------------------------------------------------------------------------
    // 3b. Neural Operation Enum (V1 production scope only)
    //     Removed: LAYERNORM, ATTENTION, SPARSE_MASK (V2 candidates)
    //-------------------------------------------------------------------------
    typedef enum logic [3:0] {
        NEURAL_OP_NOP         = 4'h0,
        NEURAL_OP_MATMUL      = 4'h1,
        NEURAL_OP_CONV2D      = 4'h2,
        NEURAL_OP_RELU        = 4'h3,
        NEURAL_OP_GELU        = 4'h4,
        NEURAL_OP_SIGMOID     = 4'h5,
        NEURAL_OP_SOFTMAX     = 4'h6,
        NEURAL_OP_RMSNORM     = 4'h7
    } neural_op_e;

    //-------------------------------------------------------------------------
    // 3c. RMSNorm Architecture Constants
    //     Method: LUT-seeded Newton-Raphson reciprocal square root
    //     Pipeline: sum(x²) → mean(x²) → +ε → LUT rsqrt → 2x NR iter → x*rsqrt
    //     Numerical Format (Derived & Frozen):
    //       Input:     Q8.8 signed (16-bit)
    //       Square:    Q16.16 unsigned (32-bit)
    //       Sum(x²):   Q22.16 unsigned (38-bit) - prevents overflow over 64 lanes
    //       Mean(x²):  Q22.16 unsigned (38-bit)
    //       rsqrt(v):  Q8.16 unsigned (24-bit)  - represents 1/sqrt(eps) up to 255.0
    //-------------------------------------------------------------------------
    localparam int RMSNORM_NR_ITERATIONS  = 2;        // 2 Newton-Raphson refinement iterations
    localparam int RMSNORM_LUT_ADDR_BITS  = 6;        // 64-entry initial approximation LUT
    localparam int RMSNORM_LUT_DATA_BITS  = 16;       // 16-bit rsqrt initial estimate
    localparam int RMSNORM_ACCUM_WIDTH    = 38;       // 38-bit Q22.16 accumulator
    localparam int RMSNORM_RSQRT_WIDTH    = 24;       // 24-bit Q8.16 rsqrt intermediate/output

    //=========================================================================
    // 4. AGENTIC AI ACCELERATOR CONSTANTS (V1 production scope)
    //     Memory Partitioning of 4MB Distributed Global Buffer:
    //       - KV Cache Storage:     2MB (1024 Pages x 2KB)  [0x0000_0000..0x001F_FFFF]
    //       - Weights/Activations:  1MB                     [0x0020_0000..0x002F_FFFF]
    //       - DMA Staging & Buffers:1MB                     [0x0030_0000..0x003F_FFFF]
    //=========================================================================
    localparam int MAX_DAG_NODES      = 64;       // Max concurrent active Agent DAG nodes
    localparam int DAG_NODE_ID_WIDTH  = 6;        // 6-bit node ID (0..63)
    localparam int KV_PAGE_SIZE_BYTES = 2048;     // 2KB Page size (1024 pages x 2KB = 2MB)
    localparam int KV_MAX_PAGES       = 1024;     // 1024 Physical KV Pages
    localparam int KV_PAGE_ID_WIDTH   = 10;       // 10-bit physical page ID
    localparam int AGENT_PRIO_LEVELS  = 8;        // 8 priority levels (0..7)
    localparam int MAX_KV_REF_COUNT   = 255;      // Max 255 shared sequence references
    localparam int KV_REFCOUNT_WIDTH  = 8;        // 8-bit reference counter

    //-------------------------------------------------------------------------
    // 4a. Agentic Operation Enum (V1: no TREE_EVAL)
    //-------------------------------------------------------------------------
    typedef enum logic [3:0] {
        AGENT_OP_NOP          = 4'h0,
        AGENT_OP_DAG_INSERT   = 4'h1,
        AGENT_OP_DAG_DEPEND   = 4'h2,
        AGENT_OP_DAG_FIRE     = 4'h3,
        AGENT_OP_KV_ALLOC     = 4'h4,
        AGENT_OP_KV_FREE      = 4'h5,
        AGENT_OP_KV_LOOKUP    = 4'h6,
        AGENT_OP_TOKEN_ROUTE  = 4'h7,
        AGENT_OP_BARRIER_SYNC = 4'h8
    } agentic_op_e;

    //-------------------------------------------------------------------------
    // 4b. Agent DAG Node Structure
    //-------------------------------------------------------------------------
    typedef struct packed {
        logic [DAG_NODE_ID_WIDTH-1:0]  node_id;
        logic [2:0]                    task_prio;
        logic [MAX_DAG_NODES-1:0]      dependency_mask; // Bitmask of prerequisite tasks
        logic [7:0]                    cluster_target;  // Target cluster or 8'hFF for dynamic
        logic [63:0]                   instruction_ptr; // 64-bit PC start address
        logic [63:0]                   context_ptr;     // 64-bit pointer to agent context state
        logic                          valid;
        logic                          ready;
        logic                          running;
        logic                          completed;
    } agent_dag_node_t;

    //-------------------------------------------------------------------------
    // 4c. Paged KV-Cache Page Table Entry Structure
    //-------------------------------------------------------------------------
    typedef struct packed {
        logic [KV_PAGE_ID_WIDTH-1:0]   physical_page;
        logic                          valid;
        logic                          dirty;
        logic [KV_REFCOUNT_WIDTH-1:0]  reference_count; // Multi-agent shared prefix cache (0..255)
        logic [15:0]                   token_count;     // Tokens stored in this page
    } paged_kv_entry_t;

    //=========================================================================
    // 5. 512-BIT SCATTER-GATHER DMA DESCRIPTOR STRUCTURE
    //=========================================================================
    typedef struct packed {
        logic [63:0]                   src_addr;        // 64-bit source physical address
        logic [63:0]                   dst_addr;        // 64-bit destination physical address
        logic [31:0]                   length;          // Transfer length in bytes
        logic [31:0]                   stride;          // Source/destination stride
        logic [7:0]                    burst_len;       // AXI burst len enc (0..255 => 1..256 beats)
        logic [7:0]                    dest_cluster;    // Target cluster ID (0..9) or broadcast
        logic                          direction;       // 1 = DRAM -> SPAD, 0 = SPAD -> DRAM
        logic                          interrupt_en;    // Assert interrupt on completion
        logic [63:0]                   next_desc_ptr;   // 64-bit pointer to next descriptor
        logic [31:0]                   flags;           // Control flags and status
    } dma_descriptor_t;


    //=========================================================================
    // 6. NETWORK-ON-CHIP (NoC) 160-BIT FLIT STRUCTURES
    //=========================================================================
    localparam int NOC_HEADER_WIDTH   = 32;       // 32-bit header width
    localparam int NOC_PAYLOAD_WIDTH  = 128;      // 128-bit payload width
    localparam int NOC_TOTAL_FLIT     = 160;      // 160-bit total flit width
    localparam int NOC_VC_COUNT       = 3;        // VC0: Req, VC1: Resp, VC2: Agentic Sync

    //-------------------------------------------------------------------------
    // 6a. Flit Type Enum (multi-flit packet protocol)
    //     FLIT_HEAD   = first flit of multi-flit packet
    //     FLIT_BODY   = middle flit(s) of multi-flit packet
    //     FLIT_TAIL   = last flit of multi-flit packet
    //     FLIT_SINGLE = complete single-flit packet (no assembly needed)
    //-------------------------------------------------------------------------
    typedef enum logic [1:0] {
        FLIT_HEAD   = 2'b00,
        FLIT_BODY   = 2'b01,
        FLIT_TAIL   = 2'b10,
        FLIT_SINGLE = 2'b11
    } flit_type_e;

    //-------------------------------------------------------------------------
    // 6b. Virtual Channel Enum
    //-------------------------------------------------------------------------
    typedef enum logic [1:0] {
        VC_REQ   = 2'b00,
        VC_RESP  = 2'b01,
        VC_AGENT = 2'b10
    } noc_vc_e;

    //-------------------------------------------------------------------------
    // 6c. Message Type Enum
    //-------------------------------------------------------------------------
    typedef enum logic [7:0] {
        MSG_MEM_REQ      = 8'h01,
        MSG_MEM_RESP     = 8'h02,
        MSG_AGENT_TASK   = 8'h03,
        MSG_AGENT_EVENT  = 8'h04,
        MSG_BARRIER_SYNC = 8'h05,
        MSG_TOKEN_ROUTE  = 8'h06
    } noc_msg_type_e;

    //-------------------------------------------------------------------------
    // 6d. Multi-Flit Packet Header (embedded in HEAD flit payload[127:96])
    //     Rules:
    //     - FLIT_SINGLE: no multiflit header needed, payload = complete message.
    //     - FLIT_HEAD:   payload[127:96] = this struct; payload[95:0] = message start.
    //     - FLIT_BODY:   payload = continuation data; same packet_id.
    //     - FLIT_TAIL:   payload = final data; same packet_id.
    //     - All flits of one packet share the same VC and XY route.
    //     - No interleaving of packets on the same VC at the same source.
    //     - Router forwards flit-by-flit; only noc_interface_adapter reassembles.
    //     - Credit-based flow control per VC; no flit drop.
    //-------------------------------------------------------------------------
    typedef struct packed {
        logic [15:0] packet_id;      // Unique packet identifier
        logic [7:0]  flit_count;     // Total flits in this packet (1..255)
        logic [7:0]  flit_index;     // Current flit index (0-based)
    } noc_multiflit_hdr_t;

    //-------------------------------------------------------------------------
    // 6e. 128-bit Memory Request Payload (64-bit Physical Address)
    //     Width verification: 64+16+16+8+1+4+19 = 128 bits ✓
    //-------------------------------------------------------------------------
    typedef struct packed {
        logic [63:0]                   addr;          // [127:64] 64-bit physical address
        logic [15:0]                   transaction_id;// [63:48]
        logic [15:0]                   byte_enable;   // [47:32]
        logic [7:0]                    burst_len;     // [31:24]
        logic                          rw_flag;       // [23]     1=write, 0=read
        logic [3:0]                    req_type;      // [22:19]
        logic [18:0]                   reserved;      // [18:0]
    } msg_mem_req_payload_t;

    //-------------------------------------------------------------------------
    // 6f. 128-bit Memory Response Payload
    //     Width verification: 16+16+64+32 = 128 bits ✓
    //-------------------------------------------------------------------------
    typedef struct packed {
        logic [15:0]                   transaction_id;// [127:112]
        logic [15:0]                   status;        // [111:96]
        logic [63:0]                   read_data;     // [95:32]
        logic [31:0]                   reserved;      // [31:0]
    } msg_mem_resp_payload_t;

    //-------------------------------------------------------------------------
    // 6g. 160-bit Unified NoC Flit Structure
    //     Width verification: 2+2+4+4+4+4+8+4+128 = 160 bits ✓
    //-------------------------------------------------------------------------
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

    //=========================================================================
    // 7. CUSTOM RISC-V ISA EXTENSION DEFINITIONS
    //=========================================================================

    //-------------------------------------------------------------------------
    // 7a. Two Custom Opcodes (RISC-V reserved for custom use)
    //-------------------------------------------------------------------------
    localparam logic [6:0] OPCODE_CUSTOM_0 = 7'b0001011; // 0x0B → Tensor/Neural
    localparam logic [6:0] OPCODE_CUSTOM_1 = 7'b0101011; // 0x2B → SIMD + Agent + Sync + Fence

    //-------------------------------------------------------------------------
    // 7b. CUSTOM-0 (0x0B): Neural/Tensor Sub-Funct3 Definitions
    //     Dispatch: funct3 selects neural operation
    //-------------------------------------------------------------------------
    localparam logic [2:0] FUNCT3_TENS_CFG       = 3'b000; // Configure tensor descriptor CSRs
    localparam logic [2:0] FUNCT3_TENS_LAUNCH    = 3'b001; // Launch async tensor computation
    localparam logic [2:0] FUNCT3_TENS_WAIT      = 3'b010; // Wait for tensor completion
    localparam logic [2:0] FUNCT3_TENS_ACT       = 3'b011; // Activation function dispatch
    localparam logic [2:0] FUNCT3_TENS_SOFTMAX   = 3'b100; // Softmax dispatch
    localparam logic [2:0] FUNCT3_TENS_NORM      = 3'b101; // RMSNorm dispatch

    //-------------------------------------------------------------------------
    // 7c. CUSTOM-1 (0x2B): Unified SIMD + Agent + Sync + Fence
    //
    //     NAMESPACE PARTITION (conflict-free, mechanically verified):
    //
    //       funct7[6] = 0  →  SIMD Vector operations (VEC_*)
    //       funct7[6] = 1  →  Agent / Sync / Fence operations
    //
    //     SIMD VECTOR (funct7[6]=0):
    //       funct7 layout: [6=0][5=op_hi][4:3=00][2:1=dtype][0=0]
    //       vec_op[3:0]  = {funct7[5], funct3[2:0]}
    //       vec_dtype    = funct7[2:1]  (00=INT8, 01=FP16, 10=INT32, 11=RSVD)
    //
    //       funct7[5]=0, funct3=000 → VEC.ADD     vec_op=4'h0
    //       funct7[5]=0, funct3=001 → VEC.SUB     vec_op=4'h1
    //       funct7[5]=0, funct3=010 → VEC.MUL     vec_op=4'h2
    //       funct7[5]=0, funct3=011 → VEC.MAC     vec_op=4'h3
    //       funct7[5]=0, funct3=100 → VEC.DOT     vec_op=4'h4
    //       funct7[5]=0, funct3=101 → VEC.REDSUM  vec_op=4'h5
    //       funct7[5]=0, funct3=110 → VEC.REDMAX  vec_op=4'h6
    //       funct7[5]=0, funct3=111 → VEC.SPLAT   vec_op=4'h7
    //       funct7[5]=1, funct3=000 → VEC.RELU    vec_op=4'h8
    //       funct7[5]=1, funct3=001 → VEC.AND     vec_op=4'h9
    //       funct7[5]=1, funct3=010 → VEC.OR      vec_op=4'hA
    //       funct7[5]=1, funct3=011 → VEC.XOR     vec_op=4'hB
    //       funct7[5]=1, funct3=1xx → RESERVED
    //
    //     AGENT/SYNC/FENCE (funct7[6]=1):
    //       Dispatch on funct3 only:
    //       funct3=000 → WARP_YIELD
    //       funct3=001 → BARRIER       (funct7[5:0] = participant mask bits)
    //       funct3=010 → AGENT_DAG
    //       funct3=011 → AGENT_KV
    //       funct3=100 → RESERVED      (was MCTS, removed V1)
    //       funct3=101 → AGENT_ROUTER
    //       funct3=110 → RESERVED
    //       funct3=111 → AI_FENCE      (funct7[1:0] = scope)
    //
    //     CONFLICT VERIFICATION: 20 unique slots, 0 collisions, 4 reserved.
    //-------------------------------------------------------------------------

    // Agent/Sync/Fence funct3 values (used when funct7[6]=1)
    localparam logic [2:0] FUNCT3_WARP_YIELD     = 3'b000;
    localparam logic [2:0] FUNCT3_BARRIER        = 3'b001;
    localparam logic [2:0] FUNCT3_AGENT_DAG      = 3'b010;
    localparam logic [2:0] FUNCT3_AGENT_KV       = 3'b011;
    // funct3=100: RESERVED (V1 — was MCTS/TREE in research)
    localparam logic [2:0] FUNCT3_AGENT_ROUTER   = 3'b101;
    // funct3=110: RESERVED
    localparam logic [2:0] FUNCT3_AI_FENCE       = 3'b111;

    //-------------------------------------------------------------------------
    // 7d. AI_FENCE Scope Encoding (within funct7[1:0], when funct7[6]=1, funct3=111)
    //
    //     AI_FENCE.SPAD   (00): Prior SPAD writes visible to subsequent
    //                           dependent reads within the same cluster.
    //     AI_FENCE.GLOBAL (01): Prior global buffer writes visible to all
    //                           clusters via NoC.
    //     AI_FENCE.DRAM   (10): Prior DMA-visible writes to external memory
    //                           are complete (DMA descriptor chain drained).
    //     AI_FENCE.RSVD   (11): Illegal — raises illegal_instruction.
    //-------------------------------------------------------------------------
    typedef enum logic [1:0] {
        AI_FENCE_SPAD   = 2'b00,
        AI_FENCE_GLOBAL = 2'b01,
        AI_FENCE_DRAM   = 2'b10,
        AI_FENCE_RSVD   = 2'b11
    } ai_fence_scope_e;

    //-------------------------------------------------------------------------
    // 7e. SIMD Vector Datatype Encoding (funct7[2:1] in VEC_* instructions)
    //-------------------------------------------------------------------------
    typedef enum logic [1:0] {
        VEC_DTYPE_INT8  = 2'b00,   // 32 lanes x 8-bit
        VEC_DTYPE_FP16  = 2'b01,   // 16 lanes x 16-bit
        VEC_DTYPE_INT32 = 2'b10,   // 8 lanes x 32-bit
        VEC_DTYPE_RSVD  = 2'b11    // Reserved — illegal
    } vec_dtype_e;

    //-------------------------------------------------------------------------
    // 7f. SIMD Vector Operation Encoding (vec_op = {funct7[5], funct3})
    //-------------------------------------------------------------------------
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

endpackage : riscv_ai_gpu_pkg
