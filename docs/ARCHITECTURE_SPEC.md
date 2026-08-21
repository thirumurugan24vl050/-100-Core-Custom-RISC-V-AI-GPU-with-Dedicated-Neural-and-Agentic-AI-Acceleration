# Technical Architecture Specification: 100-Core Custom RISC-V SIMT AI GPU
## with Dedicated Neural and Agentic AI Acceleration (RTL-to-GDSII)

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

## 4. Tile Microarchitecture (One Core = One GPU Tile)

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

### 4.1 Warp Execution & SIMT Divergence Model
- **32-Lane Logical Warp**:
  - **INT8 Mode**: 32 logical lanes $\times$ 1 element/lane $\rightarrow 32 \times 8\text{b} = 256\text{ bits}$.
  - **INT4 Mode**: 32 logical lanes $\times$ 2 packed elements/lane $\rightarrow 32 \times 2 \times 4\text{b} = 256\text{ bits}$ ($64\text{ ops}$).
  - **FP16 Mode**: 16 arithmetic elements $\rightarrow 16 \times 16\text{b} = 256\text{ bits}$.
  - **INT32 Mode**: 8 arithmetic elements $\rightarrow 8 \times 32\text{b} = 256\text{ bits}$.
- **8-Entry Reconvergence Stack**: Each warp stores up to 8 nested `{reconv_pc [31:0], reconv_mask [31:0]}` branch tokens.
- **Warp Architectural States**:
  - `WARP_READY`: Eligible for instruction issue.
  - `WARP_RUNNING`: Active in pipeline execution.
  - `WARP_WAIT_MEM`: Stalled awaiting LSU response from local scratchpad, NoC-accessed global buffer, or DMA memory service (No V1 coherent D-cache).
  - `WARP_WAIT_NMU`: Stalled awaiting tagged NMU completion (`TENS_WAIT`).
  - `WARP_WAIT_BARRIER`: Stalled at cluster barrier synchronizer (`BARRIER`).
  - `WARP_WAIT_AGENT`: Stalled awaiting agent task/event dispatch.
  - `WARP_DONE`: Thread execution terminated.

---

## 5. Custom 2-Opcode Extension & Decoupled Tensor Protocol

### 5.1 Custom Opcode Allocation
- **`CUSTOM-0 (0x0B)`: Tensor / Neural Acceleration**
  - `TENS_CFG` (`funct3=000`): Configure tensor operation descriptor via memory-mapped CSRs.
  - `TENS_LAUNCH` (`funct3=001`): Enqueue tensor job into cluster NMU command FIFO.
  - `TENS_WAIT` (`funct3=010`): Stall warp until tagged NMU job completion.
  - `TENS_ACT` (`funct3=011`): Non-linear activation execution (GELU, ReLU, Sigmoid).
  - `TENS_SOFTMAX` (`funct3=100`): 8-lane online Softmax normalization.
  - `TENS_NORM` (`funct3=101`): RMSNorm vector normalization.
- **`CUSTOM-1 (0x2B)`: SIMT / Agent Control / Synchronization**
  - `WARP_YIELD` (`funct3=000`): Voluntary context yield to next ready warp.
  - `BARRIER` (`funct3=001`): Cluster hardware barrier synchronization.
  - `AGENT_DAG_INSERT` (`funct3=010`): Insert task descriptor into hardware DAG scheduler.
  - `AGENT_DAG_FIRE` (`funct3=011`): Signal completion event for completed task ID.
  - `AGENT_KV_ALLOC` (`funct3=100`): Allocate physical KV block from free pool.
  - `AGENT_KV_LOOKUP` (`funct3=101`): Translate logical KV block to physical SRAM/DRAM address.
  - `AGENT_TOKEN_ROUTE` (`funct3=110`): Route token packet to destination cluster over NoC.

### 5.2 Decoupled Tensor Execution Sequence
```
       Host / Core Software
               │
               ▼  (Setup CSR Descriptors)
      [CSR_TENSOR_SRC_A / B / C / DIM_M / K / N]
               │
               ▼
          [TENS_CFG]
               │
               ▼
         [TENS_LAUNCH]
               │
          FIFO Full? ────► [YES: Stall Core Issuing Stage (No Drop)]
               │ [NO]
               ▼
   Cluster NMU Command FIFO (8 Entries)
   (Signals: nmu_ready, nmu_busy, nmu_done, nmu_error)
               │
               ▼
     Round-Robin Arbiter (10 Cores)
               │
               ▼
     8x8 Systolic Array (64 PEs)
               │
               ▼  (Completion Tag Broadcast)
   [cmd_id, core_id, warp_id] ──► Wake Up Blocked [TENS_WAIT]
```

---

## 6. NoC 160-Bit Flit & Gateway Architecture

```
+-----------------------------------------------------------------------------------------------+
|                               160-BIT NoC FLIT PACKET FORMAT                                  |
+-----------------------------------------------------------------------------------------------+
| [159:158] | [157:156] | [155:152] | [151:148] | [147:144] | [143:140] | [139:132]  | [131:128] | [127:0]   |
| flit_type | vc_id     | src_x     | src_y     | dst_x     | dst_y     | msg_type   | flags     | payload   |
| (2 bits)  | (2 bits)  | (4 bits)  | (4 bits)  | (4 bits)  | (4 bits)  | (8 bits)   | (4 bits)  | (128 bits)|
+-----------------------------------------------------------------------------------------------+
```

### Exact 128-Bit Payload Bit-Allocation
| `msg_type` | Name | 128-Bit Payload Field Definitions (`payload [127:0]`) | Bit Breakdown |
|---|---|---|---|
| `0x01` | `MSG_MEM_REQ` | `[127:96] addr[31:0]`<br>`[95:80] byte_enable[15:0]`<br>`[79:64] transaction_id[15:0]`<br>`[63:32] write_data[31:0]`<br>`[31:24] burst_len[7:0]`<br>`[23] rw_flag`<br>`[22:19] req_type[3:0]`<br>`[18:0] reserved[18:0]` | 32+16+16+32+8+1+4+19 = **128 bits** |
| `0x02` | `MSG_MEM_RESP` | `[127:112] transaction_id[15:0]`<br>`[111:96] status[15:0]`<br>`[95:32] read_data[63:0]`<br>`[31:0] reserved[31:0]` | 16+16+64+32 = **128 bits** |
| `0x03` | `MSG_AGENT_TASK` | `[127:120] task_id[7:0]`<br>`[119:88] parent_mask[31:0]`<br>`[87:80] prio[7:0]`<br>`[79:72] dest_cluster[7:0]`<br>`[71:40] instruction_ptr[31:0]`<br>`[39:8] context_ptr[31:0]`<br>`[7:0] reserved[7:0]` | 8+32+8+8+32+32+8 = **128 bits** |
| `0x04` | `MSG_AGENT_EVENT`| `[127:120] task_id[7:0]`<br>`[119:112] completion_code[7:0]`<br>`[111:96] event_id[15:0]`<br>`[95:64] token_val[31:0]`<br>`[63:0] reserved[63:0]` | 8+8+16+32+64 = **128 bits** |
| `0x05` | `MSG_BARRIER_SYNC`| `[127:120] cluster_id[7:0]`<br>`[119:112] barrier_id[7:0]`<br>`[111:72] warp_mask[39:0]`<br>`[71:0] reserved[72:0]` | 8+8+40+72 = **128 bits** |
| `0x06` | `MSG_TOKEN_ROUTE`| `[127:112] token_id[15:0]`<br>`[111:104] dest_cluster[7:0]`<br>`[103:8] payload_data[95:0]`<br>`[7:0] reserved[7:0]` | 16+8+96+8 = **128 bits** |

### Global Gateway Node Attachments
- **Global Agent Gateway**: Attached to **Router (0,0)**.
- **Global Memory Gateway**: Attached to **Router (9,9)**.
- **Host DMA Gateway**: Attached to **Router (5,0)**.
Gateways attach as local endpoints directly to the respective tile's 5-port router without consuming additional mesh hops.

---

## 7. Memory & DMA Architecture

```
                  External DRAM
                       ▲
                       │
          512-bit Memory-Mapped AXI Master
                       │
                      DMA
          (Descriptor Engine & Chaining)
                       │
              512-bit Internal Stream
                       │
                 Global Buffer
            (4 MB / 16 Banks x 256 KB)
                       │
                  10x10 NoC
                       │
             Cluster Scratchpad SRAM
            (64 KB / 8 Banks x 8 KB)
                       │
                 Compute Cores
```

---

## 8. Hardware Agentic AI Subsystem

### Software vs Hardware Contract
- **Software Runtime**: Executes high-level LLM reasoning, agent planning, prompt orchestration, graph generation, and high-level scheduling policy.
- **Hardware Acceleration Engine**:
  1. **Hardware DAG Task Scheduler**: 64 active task entries, dependency bitmask evaluation (target: 1 cycle), 8-level priority arbiter, dynamic cluster dispatch.
  2. **Hardware Paged KV-Cache Manager**: 1024 physical pages, logical-to-physical translation table with reference counting for zero-copy prefix sharing, supporting `ALLOC`, `FREE`, `LOOKUP`, `INC_REF`, `DEC_REF`, `PREFETCH`, and `EVICT`.
  3. **Multi-Agent Token/Event Router**: Inter-cluster event formatting and NoC dispatch.
  4. **Speculative Tree Search Engine (MCTS)**: Optional Research Extension for hardware UCT scoring and candidate branch pruning.

---

## 9. Required State Machines (FSMs) & Error Model

### 9.1 Core Subsystem FSMs
- **Core Pipeline FSM**: `FETCH` $\rightarrow$ `DECODE` $\rightarrow$ `ISSUE` $\rightarrow$ `EXECUTE` $\rightarrow$ `MEM_WAIT` $\rightarrow$ `NMU_WAIT` $\rightarrow$ `WB`.
- **NMU Engine FSM**: `IDLE` $\rightarrow$ `DEQUEUE` $\rightarrow$ `LOAD_WEIGHT` $\rightarrow$ `LOAD_ACT` $\rightarrow$ `COMPUTE` $\rightarrow$ `DRAIN` $\rightarrow$ `COMPLETE` $\rightarrow$ `ERROR`.
- **NoC Router Pipeline FSM**: `INPUT_BUFFER` $\rightarrow$ `ROUTE` $\rightarrow$ `VC_ALLOC` $\rightarrow$ `SW_ALLOC` $\rightarrow$ `TRANSFER`.
- **DMA Controller FSM**: `IDLE` $\rightarrow$ `FETCH_DESC` $\rightarrow$ `READ` $\rightarrow$ `WRITE` $\rightarrow$ `STREAM` $\rightarrow$ `COMPLETE` $\rightarrow$ `ERROR`.
- **DAG Scheduler FSM**: `IDLE` $\rightarrow$ `ALLOC` $\rightarrow$ `WAIT_DEP` $\rightarrow$ `READY` $\rightarrow$ `DISPATCH` $\rightarrow$ `COMPLETE` $\rightarrow$ `ERROR`.
- **KV Manager FSM**: `IDLE` $\rightarrow$ `ALLOCATE` $\rightarrow$ `LOOKUP` $\rightarrow$ `REF_UPDATE` $\rightarrow$ `PREFETCH` $\rightarrow$ `EVICT` $\rightarrow$ `ERROR`.

### 9.2 Unified Error Codes
`NMU_ERROR` (`0x01`), `DMA_ERROR` (`0x02`), `NOC_ERROR` (`0x03`), `KV_ERROR` (`0x04`), `DAG_ERROR` (`0x05`), `ILLEGAL_INSTR` (`0x06`), `MISALIGNED_ACCESS` (`0x07`), `FIFO_OVERFLOW` (`0x08`), `FIFO_UNDERFLOW` (`0x09`).

---

## 10. Verification Ladder & Coverage Sign-Off Criteria

### 10.1 17-Stage Verification Ladder
```
[GATE 0] Requirements & Architecture Freeze
    ↓
[GATE 1] Single AI Tile Verification (RV32IM + 4 Warps + Active Mask + 8 Reconv + SIMD + LSU)
    ↓
[GATE 2] Systolic NMU Verification (8x8 Array + Command FIFO + Skew/Drain)
    ↓
[GATE 3] Single Cluster Subsystem (10 Tiles + 64KB SPAD + NMU Arbiter + Barrier)
    ↓
[GATE 4] Single 5-Port NoC Router Verification (160b Flits + 3 VCs + XY DOR)
    ↓
[GATE 5] Small NoC Test (2x2 / 4x4 Mesh)
    ↓
[GATE 6] 10x10 Full NoC Mesh Verification
    ↓
[GATE 7] 10 Clusters / 100 Cores Integration
    ↓
[GATE 8] Global Memory + DMA + Agentic Engine Integration
    ↓
[GATE 9] Formal Coverage Closure & Signoff (IMC 100% Target)
    ↓
[GATE 10] RTL Lint (SpyGlass) / CDC / RDC / Formal Equivalence (LEC)
    ↓
[GATE 11] Logic Synthesis (Cadence Genus / Synopsys DC)
    ↓
[GATE 12] Gate-Level Simulation (GLS with SDF Timing)
    ↓
[GATE 13] Static Timing Analysis (STA at 1.0 GHz) / Power / Area
    ↓
[GATE 14] Physical Design: Floorplanning, Placement, CTS, Routing (Innovus)
    ↓
[GATE 15] Physical Verification: DRC, LVS, Dynamic IR-Drop, EM
    ↓
[GATE 16] GDSII Tapeout Readiness & Signoff
```

### 10.2 Formal Sign-Off Criteria
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

## 11. Engineering Evidence Status Classification

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
