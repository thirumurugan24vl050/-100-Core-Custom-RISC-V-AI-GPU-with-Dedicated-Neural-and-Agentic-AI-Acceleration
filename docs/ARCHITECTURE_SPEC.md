# Technical Architecture Specification: 100-Core Custom RISC-V SIMT AI GPU
## with Dedicated Neural and Agentic AI Acceleration

---

## 1. Executive Summary & Architectural Positioning

The **100-Core Custom RISC-V SIMT AI GPU** is an **ASIC-oriented RTL-to-GDSII research prototype** architected as a **domain-specific many-core accelerator**. 

The hardware microarchitecture combines the programmability of RISC-V SIMT execution with specialized tensor and agentic hardware engines:
1. **SIMT Execution Model**: 100 AI Compute Cores (RV32IM + custom 256-bit packed AI/SIMD datapath). Each core maintains 4 architectural warp contexts with a 32-lane logical warp width, SIMT active-lane mask, 8-entry branch reconvergence stack, unambiguous warp stall states, and single-cycle ready warp selection into a shared execution datapath (latency is hidden by switching to another ready warp).
2. **Dedicated Matrix Acceleration (NMU)**: 10 x 8x8 INT8 weight-stationary systolic Neural Matrix Units (640 MACs/cycle, **Theoretical Peak INT8 Throughput: 1.28 TOPS @ 1 GHz target**) controlled via a decoupled CSR descriptor interface (`TENS_CFG` -> `TENS_LAUNCH` -> `TENS_WAIT`) with 8-entry command FIFO backpressure and completion tag wake-up.
3. **Cluster Scratchpad Architecture**: 10 modular clusters, each with a 64KB banked scratchpad SRAM (8 banks x 8KB, 1R/1W per bank) featuring bank-conflict detection, round-robin arbitration, DMA ingress, and broadcast support.
4. **Physical-to-Logical 10x10 NoC Mesh & Global Gateways**: 100 5-port routers (1 router per core tile) organized as a 10x10 2D mesh, with deterministic XY routing, 3 Virtual Channels (`VC0: Request`, `VC1: Response`, `VC2: Agent/Control`), and dedicated gateway nodes for Global Agent, Global Memory, and Host DMA.
5. **Hardware Agentic AI Engine**: Hardware acceleration for software runtime tasks: 64-entry task DAG dependency resolution and priority scheduling, Hardware KV-Block Translation and Allocation Engine (PagedAttention-inspired logical-to-physical block mapping with reference counts), and token routing.
6. **Explicit Software/Hardware Memory Hierarchy**: Core (I-cache + RF) -> Cluster (64KB Scratchpad) -> Global (4MB Shared L2/Global Buffer + 512-bit DMA) -> DRAM. The DMA controller features a 512-bit memory-mapped AXI master for external memory transfers with an internal streaming datapath toward cluster scratchpads (descriptor-driven scatter-gather).

---

## 2. Frozen Architectural Parameter Set

| Parameter | Frozen Architectural Value | Derivation / Basis |
|---|---|---|
| **AI Cores** | 100 | 10 Modular Clusters x 10 Cores |
| **Clusters** | 10 | 1 Cluster per Row in 10x10 grid |
| **Cores / Cluster** | 10 | 10 Tiles per Row |
| **NoC Topology** | 10 x 10 2D-Mesh | 100 Router Nodes (1 per Core Tile) |
| **Router Ports** | 5 Ports (Local, N, S, E, W) | Dimension-Order XY Routing |
| **NoC Virtual Channels** | 3 VCs | `VC0: Req`, `VC1: Resp`, `VC2: Agent` |
| **NoC Flit Width** | 160 bits Total (32b Header + 128b Payload) | Header: Type(2), VC(2), Src(8), Dst(8), Msg(8), Flags(4) |
| **Global Gateway Nodes** | (0,0) Agent, (9,9) L2 Mem, (5,0) Host DMA | Deterministic System-Level NoC Routing Endpoints |
| **Warp Contexts / Core** | 4 Concurrent Warps | Latency Hiding Single-Cycle Selection |
| **Warp Logical Width** | 32 Lanes | 32-bit `active_mask` + 8-entry Reconvergence Stack |
| **Warp Stall States** | 7 States (`READY`, `RUNNING`, `WAIT_MEM`, `WAIT_NMU`, `WAIT_BARRIER`, `WAIT_AGENT`, `DONE`) | Unambiguous Ready Vector Generation |
| **SIMD Datapath Width** | 256 bits | 32xINT8, 64xINT4, 16xFP16, 8xINT32 |
| **NMU / Cluster** | 1 Unit (8x8 Weight-Stationary) | 64 PEs per Cluster |
| **Total Systolic PEs** | 640 PEs across Chip | 10 Clusters x 64 PEs |
| **NMU Command FIFO** | 8-Entry Queue with Backpressure | Round-robin arbitration across 10 cores with tag wake-up |
| **Scratchpad / Cluster** | 64 KB Banked SRAM | 8 Banks x 8 KB (1R/1W per bank) |
| **L2 / Global Buffer** | 4 MB Distributed SRAM | 16 Banks x 256 KB |
| **Host DMA Subsystem** | 512-bit AXI MM Master + Internal Stream | Descriptor-Driven Scatter-Gather |
| **Agent DAG Task Queue** | 64 Tasks | Dependency Bitmask & 8 Priority Levels |
| **KV-Cache Memory Pool** | 1024 Physical Blocks | Logical-to-Physical Table & Refcount Prefix Sharing |
| **Target Clock Frequency** | 1.0 GHz (`clk`) | `ASSUMED` Design Target for Synthesis |
| **Theoretical Peak INT8** | 1.28 TOPS | `DERIVED` (640 MACs/cyc x 2 ops/MAC x 1.0 GHz) |

---

## 3. Physical & Logical 10x10 Tile-to-Cluster Mapping

The 100-core accelerator is organized as a 10x10 2D grid where **one tile = one AI compute core + one local NoC router**. Adjacent tiles along each row form a cluster:

$$\text{core\_id} = y \times 10 + x, \quad \text{cluster\_id} = y$$

- **Cluster 0 (Row 0)**: Tiles $(0,0)$ through $(9,0) \longrightarrow$ Cores 0 to 9 + 64KB SPAD 0 + 8x8 NMU 0 (Tile (0,0) hosts **Global Agent Gateway**)
- **Cluster 1 (Row 1)**: Tiles $(0,1)$ through $(9,1) \longrightarrow$ Cores 10 to 19 + 64KB SPAD 1 + 8x8 NMU 1
- **Cluster 2 (Row 2)**: Tiles $(0,2)$ through $(9,2) \longrightarrow$ Cores 20 to 29 + 64KB SPAD 2 + 8x8 NMU 2
- **Cluster 3 (Row 3)**: Tiles $(0,3)$ through $(9,3) \longrightarrow$ Cores 30 to 39 + 64KB SPAD 3 + 8x8 NMU 3
- **Cluster 4 (Row 4)**: Tiles $(0,4)$ through $(9,4) \longrightarrow$ Cores 40 to 49 + 64KB SPAD 4 + 8x8 NMU 4
- **Cluster 5 (Row 5)**: Tiles $(0,5)$ through $(9,5) \longrightarrow$ Cores 50 to 59 + 64KB SPAD 5 + 8x8 NMU 5 (Tile (5,0) hosts **Host DMA Gateway**)
- **Cluster 6 (Row 6)**: Tiles $(0,6)$ through $(9,6) \longrightarrow$ Cores 60 to 69 + 64KB SPAD 6 + 8x8 NMU 6
- **Cluster 7 (Row 7)**: Tiles $(0,7)$ through $(9,7) \longrightarrow$ Cores 70 to 79 + 64KB SPAD 7 + 8x8 NMU 7
- **Cluster 8 (Row 8)**: Tiles $(0,8)$ through $(9,8) \longrightarrow$ Cores 80 to 89 + 64KB SPAD 8 + 8x8 NMU 8
- **Cluster 9 (Row 9)**: Tiles $(0,9)$ through $(9,9) \longrightarrow$ Cores 90 to 99 + 64KB SPAD 9 + 8x8 NMU 9 (Tile (9,9) hosts **Global Memory Gateway**)

---

## 4. Clocking, Reset & Clock Gating Architecture

```
                                 [External clk_in (1.0 GHz)]
                                              │
                                              ▼
                                 ┌─────────────────────────┐
                                 │   GLOBAL CLOCK BUFFER   │
                                 └────────────┬────────────┘
                                              │
                    ┌─────────────────────────┼─────────────────────────┐
                    ▼                         ▼                         ▼
        ┌───────────────────────┐ ┌───────────────────────┐ ┌───────────────────────┐
        │  Cluster 0 Clock Gater│ │  Cluster 1 Clock Gater│ │  Cluster 9 Clock Gater│
        │  (Integrated ICG Cell)│ │  (Integrated ICG Cell)│ │  (Integrated ICG Cell)│
        └───────────┬───────────┘ └───────────┬───────────┘ └───────────┬───────────┘
                    │                         │                         │
            ┌───────┴───────┐         ┌───────┴───────┐         ┌───────┴───────┐
            ▼               ▼         ▼               ▼         ▼               ▼
        10 Core Clocks   NMU/SPAD 10 Core Clocks   NMU/SPAD 10 Core Clocks   NMU/SPAD
```

- **Clock Domain**: Single synchronous clock domain at 1.0 GHz nominal (`clk`).
- **Cluster Clock Gating Enable Policy**:
  $$\text{cluster\_clk\_en} = (\text{core\_active\_mask} \ne 0) \lor \text{nmu\_busy} \lor \text{dma\_active} \lor \text{barrier\_active} \lor \text{agent\_event\_pending}$$
  Clock gating is implemented strictly with standard latch-based Integrated Clock Gating (ICG) cells, preventing combinational glitches during CTS.
- **Reset Distribution**: Active-low asynchronous assertion with 2-stage flip-flop meta-hardened synchronous de-assertion tree (`rst_n`).

---

## 5. Core Microarchitecture & SIMT Divergence Model

- **Warp Logical vs Physical SIMD Mapping**:
  The warp contains 32 logical lanes. The 256-bit packed execution engine maps data precision to logical lanes as follows:
  - **INT8 Mode**: 1 element per lane $\longrightarrow 32\text{ lanes} \times 8\text{b} = 256\text{ bits}$.
  - **INT4 Mode**: 2 packed elements per lane $\longrightarrow 32\text{ lanes} \times 2 \times 4\text{b} = 256\text{ bits}$ (64 packed operations).
  - **FP16 Mode**: 1 element per 2 lanes (16 active lanes) $\longrightarrow 16 \times 16\text{b} = 256\text{ bits}$.
  - **INT32 Mode**: 1 element per 4 lanes (8 active lanes) $\longrightarrow 8 \times 32\text{b} = 256\text{ bits}$.
- **SIMT Divergence Support**:
  - Each warp maintains a 32-bit active lane mask (`active_mask [31:0]`).
  - An **8-entry Reconvergence Stack** stores `{reconv_pc [31:0], reconv_mask [31:0]}` entries to correctly evaluate nested `if-else` divergence and reconvergence without full CPU overhead.
- **Warp Scheduling & Stall States**:
  Each warp has an explicit architectural state:
  - `WARP_READY`: Eligible for instruction issue.
  - `WARP_RUNNING`: Active in execution stage.
  - `WARP_WAIT_MEM`: Stalled awaiting D-Cache / Scratchpad load data.
  - `WARP_WAIT_NMU`: Stalled awaiting tagged NMU completion (`TENS_WAIT`).
  - `WARP_WAIT_BARRIER`: Stalled at cluster barrier (`BARRIER`).
  - `WARP_WAIT_AGENT`: Stalled awaiting agentic task/event trigger.
  - `WARP_DONE`: Execution completed / thread exited.

---

## 6. NoC 160-Bit Flit & Payload Protocol

```
+-----------------------------------------------------------------------------------------------+
|                               160-BIT NoC FLIT PACKET FORMAT                                  |
+-----------------------------------------------------------------------------------------------+
| [159:158] | [157:156] | [155:152] | [151:148] | [147:144] | [143:140] | [139:132]  | [131:128] | [127:0]   |
| flit_type | vc_id     | src_x     | src_y     | dst_x     | dst_y     | msg_type   | flags     | payload   |
| (2 bits)  | (2 bits)  | (4 bits)  | (4 bits)  | (4 bits)  | (4 bits)  | (8 bits)   | (4 bits)  | (128 bits)|
+-----------------------------------------------------------------------------------------------+
```

### Exact 128-Bit Payload Semantics per Message Type
| `msg_type` | Name | 128-Bit Payload Field Definitions (`payload [127:0]`) | Bit Breakdown |
|---|---|---|---|
| `0x01` | `MSG_MEM_REQ` | `[127:96] addr[31:0]`<br>`[95:80] byte_enable[15:0]`<br>`[79:64] transaction_id[15:0]`<br>`[63:32] write_data[31:0]`<br>`[31:24] burst_len[7:0]`<br>`[23] rw_flag`<br>`[22:19] req_type[3:0]`<br>`[18:0] reserved[18:0]` | 32+16+16+32+8+1+4+19 = **128 bits** |
| `0x02` | `MSG_MEM_RESP` | `[127:112] transaction_id[15:0]`<br>`[111:96] status[15:0]`<br>`[95:32] read_data[63:0]`<br>`[31:0] reserved[31:0]` | 16+16+64+32 = **128 bits** |
| `0x03` | `MSG_AGENT_TASK` | `[127:120] task_id[7:0]`<br>`[119:88] parent_mask[31:0]`<br>`[87:80] prio[7:0]`<br>`[79:72] dest_cluster[7:0]`<br>`[71:40] instruction_ptr[31:0]`<br>`[39:8] context_ptr[31:0]`<br>`[7:0] reserved[7:0]` | 8+32+8+8+32+32+8 = **128 bits** |
| `0x04` | `MSG_AGENT_EVENT`| `[127:120] task_id[7:0]`<br>`[119:112] completion_code[7:0]`<br>`[111:96] event_id[15:0]`<br>`[95:64] token_val[31:0]`<br>`[63:0] reserved[63:0]` | 8+8+16+32+64 = **128 bits** |
| `0x05` | `MSG_BARRIER_SYNC`| `[127:120] cluster_id[7:0]`<br>`[119:112] barrier_id[7:0]`<br>`[111:72] warp_mask[39:0]`<br>`[71:0] reserved[72:0]` | 8+8+40+72 = **128 bits** |
| `0x06` | `MSG_TOKEN_ROUTE`| `[127:112] token_id[15:0]`<br>`[111:104] dest_cluster[7:0]`<br>`[103:8] payload_data[95:0]`<br>`[7:0] reserved[7:0]` | 16+8+96+8 = **128 bits** |

### Channel Dependency Separation
- `VC0 (Request)`: Core read/write memory requests to Scratchpad and L2.
- `VC1 (Response)`: Memory read returns and write completions.
- `VC2 (Agent/Control)`: Autonomous task graph dispatches, barrier synchronization, and token routing.
- **Deadlock Assessment**: The NoC is designed for deadlock freedom using XY dimension-order routing and strict VC/channel-dependency separation. Deadlock freedom shall be validated by channel-dependency analysis and stress verification.

---

## 7. Decoupled Tensor Acceleration Interface & NMU Queueing

```
       Host / Core Runtime
               │
               ▼  (Setup Descriptors)
      [CSR_TENSOR_SRC_A / B / C / DIM_M / K / N]
               │
               ▼  (Issue Command)
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

## 8. Verification & Coverage Sign-Off Criteria

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
