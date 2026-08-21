# Technical Architecture Specification: 100-Core Custom RISC-V SIMT AI GPU
## with Dedicated Neural and Agentic AI Acceleration

---

## 1. Executive Summary & Architectural Positioning

The **100-Core Custom RISC-V SIMT AI GPU** is an **ASIC-oriented RTL-to-GDSII research prototype** architected as a **domain-specific many-core accelerator**. 

The hardware microarchitecture combines the programmability of RISC-V SIMT execution with specialized tensor and agentic hardware engines:
1. **SIMT Execution Model**: 100 AI Compute Cores (RV32IM + custom 256-bit packed AI/SIMD datapath). Each core maintains 4 architectural warp contexts with a 32-lane logical warp width, SIMT active-lane mask, reconvergence stack, and single-cycle ready warp selection into a shared execution datapath (latency is hidden by switching to another ready warp).
2. **Dedicated Matrix Acceleration (NMU)**: 10 x 8x8 INT8 weight-stationary systolic Neural Matrix Units (640 MACs/cycle, **1.28 TOPS INT8 @ 1 GHz theoretical peak**) controlled via a decoupled CSR descriptor interface (`TENS_CFG` -> `TENS_LAUNCH` -> `TENS_WAIT`).
3. **Cluster Scratchpad Architecture**: 10 modular clusters, each with a 64KB banked scratchpad SRAM (8 banks x 8KB, 1R/1W per bank) featuring bank-conflict detection, round-robin arbitration, DMA ingress, and broadcast support.
4. **Physical-to-Logical 10x10 NoC Mesh**: 100 5-port routers (1 router per core tile) organized as a 10x10 2D mesh, with deterministic XY routing and 3 Virtual Channels (`VC0: Request`, `VC1: Response`, `VC2: Agent/Control`) to prevent cyclic channel dependencies.
5. **Hardware Agentic AI Engine**: Hardware acceleration for software runtime tasks: 64-entry task DAG dependency resolution and priority scheduling, Hardware KV-Block Translation and Allocation Engine (PagedAttention-inspired logical-to-physical block mapping with reference counts), and token routing.
6. **Explicit Software/Hardware Memory Hierarchy**: Core (I-cache + RF) -> Cluster (64KB Scratchpad) -> Global (4MB Shared L2/Global Buffer + 512-bit Streaming DMA) -> DRAM, eliminating the area, timing, and verification overhead of a 100-core coherent cache hierarchy in V1.

---

## 2. Frozen Architectural Parameter Set

| Parameter | Frozen Architectural Value | Derivation / Basis |
|---|---|---|
| **AI Cores** | 100 | 10 Clusters x 10 Cores |
| **Clusters** | 10 | 1 Cluster per Row in 10x10 grid |
| **Cores / Cluster** | 10 | 10 Tiles per Row |
| **NoC Topology** | 10 x 10 2D-Mesh | 100 Router Nodes (1 per Core Tile) |
| **Router Ports** | 5 Ports (Local, N, S, E, W) | Dimension-Order XY Routing |
| **NoC Virtual Channels** | 3 VCs | `VC0: Req`, `VC1: Resp`, `VC2: Agent` |
| **NoC Flit Width** | 160 bits Total (32b Header + 128b Payload) | Header: Type(2), VC(2), Src(8), Dst(8), Msg(8), Flags(4) |
| **Warp Contexts / Core** | 4 Concurrent Warps | Latency Hiding Single-Cycle Selection |
| **Warp Logical Width** | 32 Lanes (INT8) | SIMT Active-Lane Mask (32-bit) & Reconvergence Stack |
| **SIMD Datapath Width** | 256 bits | 32xINT8, 64xINT4, 16xFP16, 8xINT32 |
| **NMU / Cluster** | 1 Unit (8x8 Weight-Stationary) | 64 PEs per Cluster |
| **Total Systolic PEs** | 640 PEs across Chip | 10 Clusters x 64 PEs |
| **NMU Command FIFO** | 8-Entry Queue | Round-robin arbitration across 10 cores with tag wake-up |
| **Scratchpad / Cluster** | 64 KB Banked SRAM | 8 Banks x 8 KB (1R/1W per bank) |
| **L2 / Global Buffer** | 4 MB Distributed SRAM | 16 Banks x 256 KB |
| **Host DMA Width** | 512 bits | AXI5 Streaming with Scatter-Gather |
| **Agent DAG Task Queue** | 64 Tasks | Dependency Bitmask & 8 Priority Levels |
| **KV-Cache Memory Pool** | 1024 Physical Blocks | Logical-to-Physical Table & Refcount Prefix Sharing |
| **Target Clock Frequency** | 1.0 GHz (`clk`) | `ASSUMED` Design Target for Synthesis |
| **Peak INT8 Performance** | 1.28 TOPS | `DERIVED` (640 MACs/cyc x 2 ops/MAC x 1.0 GHz) |

---

## 3. Physical & Logical 10x10 Tile-to-Cluster Mapping

The 100-core accelerator is organized as a 10x10 2D grid where **one tile = one AI compute core + one local NoC router**. Adjacent tiles along each row form a cluster:

$$\text{core\_id} = y \times 10 + x, \quad \text{cluster\_id} = y$$

- **Cluster 0 (Row 0)**: Tiles $(0,0)$ through $(9,0) \longrightarrow$ Cores 0 to 9 + 64KB SPAD 0 + 8x8 NMU 0
- **Cluster 1 (Row 1)**: Tiles $(0,1)$ through $(9,1) \longrightarrow$ Cores 10 to 19 + 64KB SPAD 1 + 8x8 NMU 1
- **Cluster 2 (Row 2)**: Tiles $(0,2)$ through $(9,2) \longrightarrow$ Cores 20 to 29 + 64KB SPAD 2 + 8x8 NMU 2
- **Cluster 3 (Row 3)**: Tiles $(0,3)$ through $(9,3) \longrightarrow$ Cores 30 to 39 + 64KB SPAD 3 + 8x8 NMU 3
- **Cluster 4 (Row 4)**: Tiles $(0,4)$ through $(9,4) \longrightarrow$ Cores 40 to 49 + 64KB SPAD 4 + 8x8 NMU 4
- **Cluster 5 (Row 5)**: Tiles $(0,5)$ through $(9,5) \longrightarrow$ Cores 50 to 59 + 64KB SPAD 5 + 8x8 NMU 5
- **Cluster 6 (Row 6)**: Tiles $(0,6)$ through $(9,6) \longrightarrow$ Cores 60 to 69 + 64KB SPAD 6 + 8x8 NMU 6
- **Cluster 7 (Row 7)**: Tiles $(0,7)$ through $(9,7) \longrightarrow$ Cores 70 to 79 + 64KB SPAD 7 + 8x8 NMU 7
- **Cluster 8 (Row 8)**: Tiles $(0,8)$ through $(9,8) \longrightarrow$ Cores 80 to 89 + 64KB SPAD 8 + 8x8 NMU 8
- **Cluster 9 (Row 9)**: Tiles $(0,9)$ through $(9,9) \longrightarrow$ Cores 90 to 99 + 64KB SPAD 9 + 8x8 NMU 9

---

## 4. Clocking & Reset Architecture

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
- **Reset Distribution**: Active-low asynchronous assertion with 2-stage flip-flop meta-hardened synchronous de-assertion tree (`rst_n`).

---

## 5. Core Microarchitecture & SIMT Divergence Model

```
                    AI COMPUTE CORE ARCHITECTURE (Tile x,y)
                                      │
               ┌──────────────────────▼──────────────────────┐
               │              4-Warp Context State           │
               │  Warp 0: PC0, Mask0[31:0], State0, Reconv0  │
               │  Warp 1: PC1, Mask1[31:0], State1, Reconv1  │
               │  Warp 2: PC2, Mask2[31:0], State2, Reconv2  │
               │  Warp 3: PC3, Mask3[31:0], State3, Reconv3  │
               └──────────────────────┬──────────────────────┘
                                      │
                              Warp Scheduler
                      (Single-Cycle Round-Robin/Prio)
                                      │
                              PC / Fetch Engine
                                      │
                           Instruction Decoder Unit
                                      │
               ┌──────────────────────┼──────────────────────┐
               ▼                      ▼                      ▼
         Scalar RV32IM        256-bit Packed SIMD        AI Command
          Integer ALU         Execution Engine           Interface
               │                      │                      │
               └──────────────────────┼──────────────────────┘
                                      │
                           LSU & Memory Interface
                                      │
                        Scratchpad / Local NoC Router
```

- **Warp Logical Model**: 32 logical lanes executing in lockstep over the 256-bit SIMD execution engine.
- **Divergence Support**: Each warp maintains a 32-bit active lane mask (`active_mask [31:0]`) and a 4-entry branch reconvergence stack (`reconv_pc`, `reconv_mask`) to handle branch divergence and reconvergence without full CPU overhead.
- **SIMD Precision Modes**:
  - INT8 Mode: 32 lanes x 8 bits = 256 bits.
  - INT4 Mode: 64 lanes x 4 bits = 256 bits.
  - FP16 Mode: 16 lanes x 16 bits = 256 bits.
  - INT32 Mode: 8 lanes x 32 bits = 256 bits.

---

## 6. NoC Packet & Flit Protocol

```
+-----------------------------------------------------------------------------------------------+
|                               160-BIT NoC FLIT PACKET FORMAT                                  |
+-----------------------------------------------------------------------------------------------+
| [159:158] | [157:156] | [155:152] | [151:148] | [147:144] | [143:140] | [139:132]  | [131:128] | [127:0]   |
| flit_type | vc_id     | src_x     | src_y     | dst_x     | dst_y     | msg_type   | flags     | payload   |
| (2 bits)  | (2 bits)  | (4 bits)  | (4 bits)  | (4 bits)  | (4 bits)  | (8 bits)   | (4 bits)  | (128 bits)|
+-----------------------------------------------------------------------------------------------+
```

### Channel Dependency Separation
- `VC0 (Request)`: Core read/write memory requests to Scratchpad and L2.
- `VC1 (Response)`: Memory read returns and write completions.
- `VC2 (Agent/Control)`: Autonomous task graph dispatches, barrier synchronization, and token routing.
- **Deadlock Assessment**: The NoC is designed for deadlock freedom using XY dimension-order routing and strict VC/channel-dependency separation. Deadlock freedom shall be formally validated by channel-dependency graph analysis and multi-port stress verification.

---

## 7. Decoupled Tensor Acceleration Interface

```
       Host / Core Runtime
               │
               ▼  (Setup Descriptors)
      [CSR_TENSOR_SRC_A / B / C / DIM_M / K / N]
               │
               ▼  (Issue Command)
          [TENS_LAUNCH]
               │
               ▼
   Cluster NMU Command FIFO (8 Entries)
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
| 1.28 TOPS Peak Throughput | `DERIVED` | 10 clusters x 64 MACs/cycle x 2 ops/MAC x 1.0 GHz |
| Target 1.0 GHz Frequency | `ASSUMED` | Target synthesis constraint in SDC |
| NoC Deadlock Freedom | `UNVERIFIED` | Strict VC separation under XY DOR; formal CDG analysis planned |
| Full-Chip Regression (84/84 Tests) | `VERIFIED` | Executed simulator logs in Cadence Incisive / Vivado XSim |
| Post-Synthesis Timing & Power | `UNVERIFIED` | Awaiting full-chip Genus/Innovus synthesis run on Linux EDA server |
| GDSII Tapeout Readiness | `BLOCKED` | Awaiting physical design routing and foundry DRC/LVS rule decks |
