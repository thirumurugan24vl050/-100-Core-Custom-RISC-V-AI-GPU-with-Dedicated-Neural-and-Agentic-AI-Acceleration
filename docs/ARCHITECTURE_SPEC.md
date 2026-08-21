# Technical Architecture Specification: Architecture Baseline v1.0
## 100-Core Custom RISC-V SIMT AI GPU with Dedicated Neural and Agentic AI Acceleration (RTL-to-GDSII)

---

## 1. Project Definition & Executive Summary

**Project Title**: RTL-to-GDSII Implementation of a 100-Core Custom RISC-V SIMT AI GPU with Dedicated Neural and Agentic AI Acceleration.

**Architectural Positioning**:
An ASIC-oriented, domain-specific many-core AI accelerator combining programmable RISC-V scalar execution, GPU-style SIMT warp scheduling, packed AI/SIMD datapath execution, dedicated systolic tensor acceleration, explicit scratchpad/global-buffer memory movement, and hardware primitives for agent-task scheduling and paged KV-cache management. The architecture is explicitly specialized for AI inference and agentic workloads (not a general-purpose desktop graphics GPU replacement).

---

## 2. Golden Frozen Architectural Parameters

| Parameter | Frozen Value | Microarchitectural Specification & Contract |
|---|---|---|
| **Total AI Cores** | **100 Cores** | 10 Modular Compute Clusters $\times$ 10 Cores |
| **Compute Clusters** | **10 Clusters** | 1 Cluster per Row in 10$\times$10 2D-Mesh Grid |
| **Cores per Cluster** | **10 Cores** | 10 Tiles per Row |
| **Physical Tile Mapping** | **Tile $(x, y)$** | $\text{core\_id} = y \times 10 + x, \quad \text{cluster\_id} = y$ |
| **Tile Definition** | **1 Core + 1 Router** | 1 RISC-V AI Compute Core + 1 5-Port NoC Router Endpoint |
| **System Address Width** | **64 bits Physical** | `addr[63:0]` for Global Memory, DMA, and External DRAM |
| **NoC Interconnect** | **10 $\times$ 10 2D-Mesh** | 100 5-Port Routers with Dimension-Order XY Routing |
| **Router Ports** | **5 Ports** | North, South, East, West, Local |
| **NoC Virtual Channels** | **3 VCs** | `VC0: Request`, `VC1: Response`, `VC2: Agent/Control` |
| **Total Flit Width** | **160 bits** | 32-bit Authoritative Header + 128-bit Packed Payload |
| **Global Gateways** | **(0,0), (9,9), (5,0)** | (0,0) Agent Gateway, (9,9) Memory Gateway, (5,0) Host DMA Gateway |
| **Warp Contexts / Core** | **4 Warps** | Hardware contexts ($W_0..W_3$) with single-cycle ready selection |
| **Logical Warp Width** | **32 Lanes** | 32-bit `active_mask` + 8-entry Reconvergence Stack per warp |
| **Warp Stall States** | **7 States** | `WARP_READY`, `WARP_RUNNING`, `WARP_WAIT_MEM`, `WARP_WAIT_NMU`, `WARP_WAIT_BARRIER`, `WARP_WAIT_AGENT`, `WARP_DONE` |
| **Scalar ISA** | **RV32IM** | Integer ALU + Multiplier/Divider (`MUL`, `MULH`, `DIV`, `REM`) |
| **Packed SIMD Datapath** | **256 bits** | INT8 (32 lanes), INT4 (64 ops), FP16 (16 lanes), INT32 (8 lanes) |
| **Systolic NMUs** | **10 NMUs** | 1 Unit (8x8 Weight-Stationary PE Array) per Cluster |
| **Total Systolic PEs** | **640 PEs** | 10 Clusters $\times$ 64 PEs ($640\text{ MACs/cycle}$) |
| **NMU Data Type (V1)** | **INT8 $\times$ INT8 $\rightarrow$ INT32** | Signed 8-bit inputs with 32-bit accumulation |
| **NMU Command FIFO** | **8 Entries / Cluster** | Round-robin arbitration across 10 cores; stall on full (no drop) |
| **Scratchpad / Cluster** | **64 KB Banked SRAM** | 8 Banks $\times$ 8 KB (1R/1W per bank with conflict arbitration) |
| **Global Buffer** | **4 MB Distributed SRAM** | 16 Banks $\times$ 256 KB with multi-master arbitration |
| **Host DMA Subsystem** | **512-bit AXI Master** | 512-bit Memory-Mapped AXI Master + Internal Stream toward SPAD |
| **Agent DAG Task Queue** | **64 Tasks** | Single-cycle dependency bitmask target + 8 priority levels |
| **KV-Cache Memory Pool** | **1024 Physical Blocks** | Logical-to-Physical Table + Reference Count for Prefix Sharing |
| **Clocking Architecture** | **1 Synchronous Domain** | 1.0 GHz target (`clk`) with latch-based ICG per cluster |
| **Reset Architecture** | **Async Assert / Sync Deassert** | 2-stage flip-flop meta-hardened reset distribution (`rst_n`) |
| **Theoretical Peak INT8** | **1.28 TOPS** | `DERIVED` ($640\text{ MAC/cyc} \times 2\text{ ops/MAC} \times 1.0\text{ GHz}$) |

---

## 3. Top-Level System Architecture

```
                           ┌───────────────────────────┐
                           │ 100-CORE RISC-V AI GPU   │
                           │           TOP             │
                           └─────────────┬─────────────┘
                                         │
       ┌─────────────────────────────────┼─────────────────────────────────┐
       │                                 │                                 │
       ▼                                 ▼                                 ▼
┌───────────────┐              ┌────────────────────┐              ┌────────────────┐
│ Agent Engine  │              │ Global Memory      │              │ Host / DMA     │
│               │              │                    │              │                │
│ DAG Scheduler │              │ 4MB Global Buffer  │              │ 512-bit AXI    │
│ KV Manager    │              │ 16 Banks           │              │ DMA Master     │
│ Token Router  │              │ Memory Gateway     │              │ SG Descriptors │
└───────┬───────┘              └─────────┬──────────┘              └───────┬────────┘
        │                                │                                 │
   Gateway (0,0)                    Gateway (9,9)                     Gateway (5,0)
        │                                │                                 │
        └────────────────────────────────┼─────────────────────────────────┘
                                         │
                               ┌─────────▼─────────┐
                               │    10 × 10 NoC    │
                               │    100 Routers    │
                               └─────────┬─────────┘
                                         │
                ┌────────────────────────┼────────────────────────┐
                │                        │                        │
                ▼                        ▼                        ▼
          ┌──────────┐             ┌──────────┐             ┌──────────┐
          │Cluster 0 │    ...      │Cluster 1 │    ...      │Cluster 9 │
          │10 cores  │             │10 cores  │             │10 cores  │
          │64KB SPAD │             │64KB SPAD │             │64KB SPAD │
          │8×8 NMU   │             │8×8 NMU   │             │8×8 NMU   │
          └──────────┘             └──────────┘             └──────────┘
```

---

## 4. Tile Microarchitecture & Core Pipeline Control

```
                              AI COMPUTE TILE (x, y)
                                        │
                         ┌──────────────▼──────────────┐
                         │       4 Warp Contexts       │
                         │                             │
                         │ W0 W1 W2 W3                 │
                         │ PC                          │
                         │ active_mask[31:0]           │
                         │ warp_state [2:0]            │
                         │ reconvergence stack [8]     │
                         └──────────────┬──────────────┘
                                        │
                                 Warp Scheduler
                         (Single-Cycle Ready Selection)
                                        │
                                 Fetch / Decode
                                        │
                           ┌────────────┼────────────┐
                           │            │            │
                           ▼            ▼            ▼
                       Scalar ALU    256b SIMD     AI Command
                         RV32IM        Unit        Interface
                           │            │            │
                           └────────────┼────────────┘
                                        │
                                   LSU / Memory
                                        │
                               Local SPAD / Local NoC
```

### 4.1 Core Pipeline and Stall/Wait Control
The core execution pipeline operates as a dynamic, warp-interleaved datapath:
```
Fetch ──► Decode ──► Issue ──► Execute ──┬──► Scalar Result ──► Writeback (WB)
                                         ├──► Memory Request ──► WARP_WAIT_MEM
                                         ├──► Tensor Request ──► WARP_WAIT_NMU
                                         ├──► Barrier Sync   ──► WARP_WAIT_BARRIER
                                         └──► Agent Request  ──► WARP_WAIT_AGENT
```

### 4.2 SIMT Divergence & Precision Model
- **32-Lane Logical Warp**:
  - **INT8 Mode**: 32 logical lanes $\times$ 1 element/lane $\rightarrow 32 \times 8\text{b} = 256\text{ bits}$.
  - **INT4 Mode**: 32 logical lanes $\times$ 2 packed elements/lane $\rightarrow 32 \times 2 \times 4\text{b} = 256\text{ bits}$ ($64\text{ ops}$).
  - **FP16 Mode**: 16 arithmetic elements $\rightarrow 16 \times 16\text{b} = 256\text{ bits}$.
  - **INT32 Mode**: 8 arithmetic elements $\rightarrow 8 \times 32\text{b} = 256\text{ bits}$.
- **8-Entry Reconvergence Stack**: Stores `{reconv_pc [31:0], reconv_mask [31:0]}` for nested `if-else` divergence.

---

## 5. Custom ISA Extensions & Decoupled Accelerator Protocol

### 5.1 Custom Opcode Space
- **`CUSTOM-0 (0x0B)`: Tensor & Neural Acceleration**
  - `TENS_CFG` (`funct3=000`): Configure tensor operation descriptor registers.
  - `TENS_LAUNCH` (`funct3=001`): Asynchronous GEMM dispatch to cluster NMU command FIFO.
  - `TENS_WAIT` (`funct3=010`): Blocking warp synchronization waiting on accelerator tag `{core_id, warp_id, cmd_id}`.
  - `TENS_ACT` (`funct3=011`): Asynchronous Activation dispatch (GELU, ReLU, Sigmoid).
  - `TENS_SOFTMAX` (`funct3=100`): Asynchronous 8-lane Online Softmax normalization dispatch.
  - `TENS_NORM` (`funct3=101`): Asynchronous RMSNorm vector normalization dispatch.
- **`CUSTOM-1 (0x2B)`: SIMT / Agent Control / Memory Barrier**
  - `WARP_YIELD` (`funct3=000`): Voluntary context yield to next ready warp.
  - `BARRIER` (`funct3=001`): Cluster hardware barrier synchronization.
  - `AGENT_DAG_INSERT` (`funct3=010`): Insert task descriptor into hardware DAG scheduler.
  - `AGENT_DAG_FIRE` (`funct3=011`): Signal completion event for completed task ID.
  - `AGENT_KV_ALLOC` (`funct3=100`): Allocate physical KV block from free pool.
  - `AGENT_KV_LOOKUP` (`funct3=101`): Translate logical KV block to physical 64-bit address.
  - `AGENT_TOKEN_ROUTE` (`funct3=110`): Route token packet to destination cluster over NoC.
  - `AI_FENCE` (`funct3=111`): Memory fence ensuring all prior writes are globally visible.

### 5.2 Cluster Hardware Barrier Synchronization Semantics
- **Barrier Organization**: 16 concurrent barrier instances per cluster (`barrier_id [3:0]`).
- **Participant Masks**:
  - `participant_mask [39:0]`: Bitmask of participating warps (10 cores $\times$ 4 warps = 40 warps).
  - `arrival_mask [39:0]`: Registered mask tracking arrived warps.
- **Release Condition**:
  $$\text{Release} = (\text{arrival\_mask} == \text{participant\_mask})$$
  - Barrier 0: Global cluster synchronization across all 40 active warps.
  - Barriers 1..15: Dynamically configured participant subsets for fine-grained warp grouping.

---

## 6. Memory Model, Synchronization & 64-bit DMA

### 6.1 Explicit Software-Managed Memory Ordering
- **Memory Model**: Explicit software-managed synchronization; no implicit hardware cache coherence in V1.
- **Ordering Semantics**:
  - **Core Loads/Stores**: Strictly ordered within each individual warp context.
  - **DMA $\rightarrow$ SPAD Transfers**: Completion event/interrupt establishes memory visibility.
  - **SPAD $\rightarrow$ DMA Transfers**: Explicit `AI_FENCE` ensures SPAD writeback before DMA launch.
  - **NMU $\rightarrow$ SPAD Transfers**: NMU completion tag broadcast establishes visibility before `TENS_WAIT` unblocks warp.
  - **Agent Events**: Event firing establishes task dependency and output data visibility.

### 6.2 512-bit Scatter-Gather DMA Descriptor Structure
```systemverilog
typedef struct packed {
    logic [63:0]  src_addr;         // 64-bit source physical address
    logic [63:0]  dst_addr;         // 64-bit destination physical address
    logic [31:0]  length;           // Transfer length in bytes
    logic [31:0]  stride;           // Source/destination stride
    logic [7:0]   burst_len;        // AXI burst length (1..256 beats)
    logic [7:0]   dest_cluster;     // Target cluster ID (0..9) or broadcast
    logic         direction;        // 1 = DRAM -> SPAD, 0 = SPAD -> DRAM
    logic         interrupt_en;     // Assert interrupt on completion
    logic [63:0]  next_desc_ptr;    // 64-bit pointer to next descriptor (64'h0 = terminal)
    logic [31:0]  flags;            // Control flags and status
} dma_descriptor_t;
```

---

## 7. NoC 160-Bit Flit & 64-Bit System Addressing

```
+-----------------------------------------------------------------------------------------------+
|                               160-BIT NoC FLIT PACKET FORMAT                                  |
+-----------------------------------------------------------------------------------------------+
| [159:158] | [157:156] | [155:152] | [151:148] | [147:144] | [143:140] | [139:132]  | [131:128] | [127:0]   |
| flit_type | vc_id     | src_x     | src_y     | dst_x     | dst_y     | msg_type   | flags     | payload   |
| (2 bits)  | (2 bits)  | (4 bits)  | (4 bits)  | (4 bits)  | (4 bits)  | (8 bits)   | (4 bits)  | (128 bits)|
+-----------------------------------------------------------------------------------------------+
```

### Exact 128-Bit Payload Bit-Allocation (64-bit Physical Address)
| `msg_type` | Name | 128-Bit Payload Field Definitions (`payload [127:0]`) | Bit Breakdown |
|---|---|---|---|
| `0x01` | `MSG_MEM_REQ` | `[127:64] addr[63:0]`<br>`[63:48] transaction_id[15:0]`<br>`[47:32] byte_enable[15:0]`<br>`[31:24] burst_len[7:0]`<br>`[23] rw_flag`<br>`[22:19] req_type[3:0]`<br>`[18:0] reserved[18:0]` | 64+16+16+8+1+4+19 = **128 bits** |
| `0x02` | `MSG_MEM_RESP` | `[127:112] transaction_id[15:0]`<br>`[111:96] status[15:0]`<br>`[95:32] read_data[63:0]`<br>`[31:0] reserved[31:0]` | 16+16+64+32 = **128 bits** |
| `0x03` | `MSG_AGENT_TASK` | `[127:120] task_id[7:0]`<br>`[119:88] parent_mask[31:0]`<br>`[87:80] prio[7:0]`<br>`[79:72] dest_cluster[7:0]`<br>`[71:40] instruction_ptr[31:0]`<br>`[39:8] context_ptr[31:0]`<br>`[7:0] reserved[7:0]` | 8+32+8+8+32+32+8 = **128 bits** |
| `0x04` | `MSG_AGENT_EVENT`| `[127:120] task_id[7:0]`<br>`[119:112] completion_code[7:0]`<br>`[111:96] event_id[15:0]`<br>`[95:64] token_val[31:0]`<br>`[63:0] reserved[63:0]` | 8+8+16+32+64 = **128 bits** |
| `0x05` | `MSG_BARRIER_SYNC`| `[127:120] cluster_id[7:0]`<br>`[119:112] barrier_id[7:0]`<br>`[111:72] warp_mask[39:0]`<br>`[71:0] reserved[72:0]` | 8+8+40+72 = **128 bits** |
| `0x06` | `MSG_TOKEN_ROUTE`| `[127:112] token_id[15:0]`<br>`[111:104] dest_cluster[7:0]`<br>`[103:8] payload_data[95:0]`<br>`[7:0] reserved[7:0]` | 16+8+96+8 = **128 bits** |

---

## 8. Verification Ladder & Coverage Sign-Off Criteria

### 8.1 17-Stage Verification Ladder
```
[GATE 0]  Requirements & Architecture Specification Freeze (Architecture Baseline v1.0)
    ↓
[GATE 1]  Single AI Tile Microarchitecture (riscv_ai_tile.sv)
    ↓
[GATE 2]  Systolic NMU (neural_systolic_engine_8x8.sv)
    ↓
[GATE 3]  Single Cluster Subsystem (ai_gpu_cluster.sv)
    ↓
[GATE 4]  Single 5-Port Router (noc_router_5port.sv)
    ↓
[GATE 5]  Small NoC Mesh (2x2 / 4x4)
    ↓
[GATE 6]  Full 10x10 NoC Mesh
    ↓
[GATE 7]  10-Cluster / 100-Core Compute Grid
    ↓
[GATE 8]  Global Memory + DMA + Agentic Coprocessor
    ↓
[GATE 9]  Coverage Closure & Verification Signoff — IMC
    ↓
[GATE 10] RTL Lint (SpyGlass) / CDC / RDC / Formal Equivalence (LEC)
    ↓
[GATE 11] Logic Synthesis (Cadence Genus / Synopsys DC)
    ↓
[GATE 12] Gate-Level Simulation (GLS with Timing Annotation)
    ↓
[GATE 13] Static Timing Analysis (STA @ 1.0 GHz) / Power / Area
    ↓
[GATE 14] Physical Design: Floorplanning, Placement, CTS, Routing (Innovus)
    ↓
[GATE 15] Physical Verification: DRC, LVS, Dynamic IR-Drop, EM
    ↓
[GATE 16] GDSII Tapeout Readiness & Sign-Off
```

### 8.2 Formal Coverage Targets
```text
================================================================================
 [CADENCE INCISIVE / IMC COVERAGE SIGNOFF TARGETS]
================================================================================
 Metric                             | Target Sign-Off Criterion
------------------------------------+-------------------------------------------
 Block Coverage                     | >= 100%* (with documented review of tie-offs)
 Expression Coverage                | >= 100%*
 Toggle Coverage                    | >= 100%*
 FSM State Coverage                 | 100.0%
 FSM Transition Coverage            | 100.0%
 Assertion Coverage                 | 100.0% applicable SVA properties
 Functional Coverage                | 100.0% planned covergroups and crosses
================================================================================
```

---

## 9. Engineering Evidence Status Classification

| Architectural Claim | Evidence Status | Basis of Evaluation |
|---|---|---|
| 100-Core SIMT Architecture | `DERIVED` | 10 clusters x 10 cores, core_id = y*10+x |
| 8x8 Systolic NMU Logic | `VERIFIED` | Verified against mathematical matrix multiplication golden model |
| Theoretical Peak 1.28 TOPS | `DERIVED` | 10 clusters x 64 MACs/cycle x 2 ops/MAC x 1.0 GHz |
| Target 1.0 GHz Frequency | `ASSUMED` | Target synthesis constraint in SDC |
| NoC Deadlock Freedom | `UNVERIFIED` | Strict VC separation under XY DOR; formal CDG analysis planned |
| Full-Chip Regression (84/84 Tests) | `VERIFIED` | Executed simulator logs in Cadence Incisive / Vivado XSim |
| Full-Chip Code & Functional Coverage | `UNVERIFIED` | Measured per-gate independently toward signoff targets |
| Post-Synthesis Timing & Power | `UNVERIFIED` | Awaiting full-chip Genus/Innovus synthesis run on Linux EDA server |
| GDSII Tapeout Readiness | `BLOCKED` | Awaiting physical design routing and foundry DRC/LVS rule decks |
