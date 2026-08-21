# 100-Core Custom RISC-V AI GPU with Dedicated Neural & Agentic AI Acceleration
### *ASIC-Oriented RTL-to-GDSII Research Prototype for Scalable Many-Core AI Acceleration*

[![IEEE 1800-2017](https://img.shields.io/badge/Standard-IEEE%201800--2017%20SystemVerilog-blue.svg)](https://standards.ieee.org/)
[![Regression Status](https://img.shields.io/badge/Regression-9%2F9%20PASS%20(100%25)-brightgreen.svg)]()
[![EDA Tools](https://img.shields.io/badge/EDA-Vivado%20%7C%20Cadence%20Genus-orange.svg)]()
[![Architecture](https://img.shields.io/badge/Architecture-100--Core%20%7C%2010x10%20NoC%20%7C%20Agentic%20AI-purple.svg)]()

---

## 1. Executive Architectural Overview

The **100-Core Custom RISC-V AI GPU** is a domain-specific, massively parallel accelerator designed specifically for acceleration of **Transformer/LLM Neural Workloads (Tensor Acceleration)** and **Autonomous Multi-Agent Graph Workloads (Agentic AI Acceleration)**.

```
+--------------------------------------------------------------------------------------------------+
|                                    100-CORE RISC-V AI GPU TOP                                    |
|                                                                                                  |
|  +--------------------------------+  +--------------------------------+  +--------------------+  |
|  |     GLOBAL AGENTIC AI ENGINE   |  |   HIGH-SPEED AXI5 / DMA ENGINE |  |   GLOBAL PLL /     |  |
|  |  * Dynamic Task DAG Scheduler  |  |  * 512-bit Host Memory Bus     |  |   RESET CONTROLLER |  |
|  |  * Paged KV-Cache Directory    |  |  * Multi-Channel DMA           |  |  * Synchronous     |  |
|  |  * Speculative MCTS Tree Unit  |  |  * Scatter-Gather Buffer       |  |    De-assertion    |  |
|  |  * Priority Token Router       |  +--------------------------------+  +--------------------+  |
|  +--------------------------------+                                                              |
|                                                                                                  |
|  +--------------------------------------------------------------------------------------------+  |
|  |                     10x10 2D-MESH NETWORK-ON-CHIP (NoC) INTERCONNECT                       |  |
|  |             (XY Wormhole Routing, Credit-Based Flow Control, 3 Virtual Channels)           |  |
|  +--------------------------------------------------------------------------------------------+  |
|         |                  |                  |                  |                  |            |
|  +--------------+  +--------------+  +--------------+  +--------------+  +--------------+        |
|  |  CLUSTER 0   |  |  CLUSTER 1   |  |  CLUSTER 2   |  |  CLUSTER 3   |  |  CLUSTER 9   | ...    |
|  | (Cores 00-09)|  | (Cores 10-19)|  | (Cores 20-29)|  | (Cores 30-39)|  | (Cores 90-99)|        |
|  | * 10 RV Cores|  | * 10 RV Cores|  | * 10 RV Cores|  | * 10 RV Cores|  | * 10 RV Cores|        |
|  | * Neural 8x8 |  | * Neural 8x8 |  | * Neural 8x8 |  | * Neural 8x8 |  | * Neural 8x8 |        |
|  | * GELU/Softmx|  | * GELU/Softmx|  | * GELU/Softmx|  | * GELU/Softmx|  | * GELU/Softmx|        |
|  | * 64KB SRAM  |  | * 64KB SRAM  |  | * 64KB SRAM  |  | * 64KB SRAM  |  | * 64KB SRAM  |        |
|  | * Warp Sync  |  | * Warp Sync  |  | * Warp Sync  |  | * Warp Sync  |  | * Warp Sync  |        |
|  +--------------+  +--------------+  +--------------+  +--------------+  +--------------+        |
|                                                                                                  |
|  +--------------------------------------------------------------------------------------------+  |
|  |                DISTRIBUTED BANKED L2 CACHE & COHERENT MEMORY DIRECTORY                    |  |
|  |                          (16 Banks x 256KB = 4MB On-Chip SRAM)                             |  |
|  +--------------------------------------------------------------------------------------------+  |
+--------------------------------------------------------------------------------------------------+
```

---

## 2. Three-Level Architectural Hierarchy

```
                    100-Core RISC-V AI GPU Top
                              |
                    +---------+---------+
                    | Global Agent Engine|
                    | DMA / Memory Ctrl  |
                    +---------+---------+
                              |
                     10 x 10 2D-Mesh NoC
                              |
        +---------------------+---------------------+
        |                     |                     |
    Cluster 0             Cluster 1            Cluster 9
    10 cores              10 cores              10 cores
        |                     |                     |
   +----+----+           +----+----+           +----+----+
   | RV Core | ...       | RV Core | ...       | RV Core |
   | Vector  |           | Vector  |           | Vector  |
   | MAC/Tens|           | MAC/Tens|           | MAC/Tens|
   +---------+           +---------+           +---------+
        |                     |                     |
     8x8 NMU               8x8 NMU               8x8 NMU
```

### Level 1: Custom RISC-V AI Core (`rtl/core/`)
- **Base ISA**: Lightweight RV32I 5-stage scalar pipeline with zero-overhead branch evaluation.
- **256-Bit Vector SIMD Engine**: Parallel execution for INT8x32, FP16x16, INT32x8, vector dot-products, and reduction trees.
- **4-Warp Multithreading**: Round-robin latency-hiding warp scheduler with register busy scoreboard.
- **Custom Instruction Set Extensions**:
  - `0x0B`: Tensor / NMU Operations (`TENS.MATMUL`, `TENS.ACT`, `TENS.SOFTMAX`, `TENS.NORM`)
  - `0x2B`: Vector SIMD Operations (`VEC.ADD`, `VEC.SUB`, `VEC.MUL`, `VEC.DOT`, `VEC.REDSUM`, `VEC.REDMAX`, `VEC.SPLAT`, `VEC.RELU`)
  - `0x5B`: Agentic Control Primitives (`AGENT.DAG_INSERT`, `AGENT.DAG_FIRE`, `AGENT.KV_ALLOC`, `AGENT.KV_FREE`, `AGENT.KV_LOOKUP`, `AGENT.TREE_EVAL`, `AGENT.TOKEN_ROUTE`)
  - `0x7B`: Cluster Synchronization (`BARRIER.SYNC`, `WARP.YIELD`)

### Level 2: GPU Compute Cluster (`rtl/cluster/`, `rtl/neural/`)
- **10 RV32 AI Cores**: High-density compute group.
- **8x8 Neural Matrix Unit (NMU)**: Weight-stationary 2D systolic GEMM array (64 PEs) with row/column skew registers.
- **Activation & Normalization Unit**: Pipelined hardware for GELU, ReLU, Sigmoid, RMSNorm, and 8-lane online Softmax.
- **64KB Banked Scratchpad SRAM**: 8 banks x 8KB multi-port SRAM with conflict crossbar arbiter.
- **40-Warp Hardware Barrier Synchronizer**: Single-cycle cluster-wide synchronization broadcast.

### Level 3: AI GPU SoC (`rtl/top/`, `rtl/agentic/`, `rtl/noc/`, `rtl/memory/`)
- **10x10 2D-Mesh Network-on-Chip (NoC)**: 5-port Virtual Channel routers with deadlock-free XY Dimension-Order Routing (DOR).
- **Dedicated Hardware Agentic AI Coprocessor**:
  - *64-Node Task DAG Scheduler*: Single-cycle dependency bitmask evaluation and 8-level priority dispatch.
  - *1024-Page Paged KV-Cache Manager*: 1-cycle find-first-free allocation bitmap and zero-copy prefix sharing.
  - *MCTS Speculative Tree Search Engine*: Hardware UCT score evaluation and temperature branch pruning.
  - *Token & Context Router*: Inter-agent packetization across the NoC grid.
- **Distributed Memory Subsystem**: 4MB banked L2 Cache (16 banks x 256KB), directory controller, and 512-bit streaming DMA master.

---

## 3. Verification & Regression Signoff Matrix

| # | Testbench | Subsystem Tested | Verification Scope | Result |
| :---: | :--- | :--- | :--- | :---: |
| 1 | `tb_riscv_ai_core` | Core Pipeline (Level 1) | RV32I ALU, Multiplier, 256-bit Vector SIMD, 4 Warps, LSU | **PASS** |
| 2 | `tb_neural_systolic_engine` | Neural GEMM (Level 2) | 8x8 Weight-Stationary Matrix Unit vs Mathematical Golden Model | **PASS** |
| 3 | `tb_neural_activation` | Neural Activations (Level 2) | GELU polynomial curve, ReLU, Sigmoid, 8-Lane Online Softmax | **PASS** |
| 4 | `tb_agent_dag_scheduler` | Agent Coprocessor (Level 3) | 64-Node DAG dependency bitmask evaluation & 8-Level Priority | **PASS** |
| 5 | `tb_paged_kv_cache_mgr` | Memory Manager (Level 3) | 1024-Page allocation bitmap, Table Walker, Zero-Copy Sharing | **PASS** |
| 6 | `tb_agent_tree_search` | Speculative MCTS (Level 3) | UCT scoring, unvisited node exploration, temperature pruning | **PASS** |
| 7 | `tb_noc_router_5port` | 2D-Mesh NoC (Level 3) | 5-Port VC Router XY DOR routing, local/remote packet delivery | **PASS** |
| 8 | `tb_ai_gpu_cluster` | 10-Core Cluster (Level 2) | 10 Cores parallel compute, 64KB SRAM Crossbar, Barrier Sync | **PASS** |
| 9 | `tb_riscv_ai_gpu_top` | 100-Core SoC (Level 3) | Full 100-Core Top, Host CSR Telemetry, 512-bit DMA Burst into L2 | **PASS** |

```text
================================================================================
 [REGRESSION SUMMARY REPORT]
 Total Testbenches Run: 9
 Total PASSED:          9
 Total FAILED:          0
================================================================================
 >>> 100% REGRESSION CLOSURE ACHIEVED - READY FOR LOGIC SYNTHESIS / GDSII FLOW <<<
```

---

## 4. Repository Structure

```
.
├── rtl/
│   ├── include/          # Global package, constants, ISA definitions
│   ├── core/             # RV32I scalar pipeline, vector unit, warp scheduler, regfile, LSU
│   ├── neural/           # 8x8 Systolic GEMM array, PEs, GELU/ReLU/Softmax units
│   ├── agentic/          # 64-node DAG scheduler, paged KV-cache, MCTS tree search, token router
│   ├── noc/              # 5-port VC NoC router and network interface adapter
│   ├── cluster/          # 10-core cluster top, 64KB banked SRAM scratchpad, barrier sync
│   ├── memory/           # 4MB banked L2 cache, directory controller, 512-bit streaming DMA
│   └── top/              # Full-chip 100-core SoC top level (riscv_ai_gpu_top)
├── tb/
│   ├── unit_tb/          # Dedicated unit testbenches for all sub-modules
│   ├── cluster_tb/       # 10-core cluster concurrency and scratchpad testbench
│   └── top_tb/           # 100-core full-chip SoC top-level testbench
├── docs/
│   ├── ARCHITECTURE_SPEC.md            # Comprehensive architecture specification
│   ├── MICROARCHITECTURE_ASM_CHARTS.md # Formal ASM state diagrams & control contracts
│   ├── VERIFICATION_PLAN_AND_COVERAGE.md# Multi-tier verification plan & coverage matrix
│   ├── TRACEABILITY_MATRIX.md          # Bidirectional Requirements-to-RTL traceability
│   └── PHYSICAL_DESIGN_PLAN.md         # Floorplan, CTS H-tree, PDN mesh, and PPA signoff
└── scripts/
    ├── constraints.sdc        # 1.0 GHz SDC timing constraints
    ├── synth_genus.tcl        # Cadence Genus synthesis script
    ├── run_sim.ps1            # Single testbench runner
    └── run_all_regressions.ps1# Automated 9-testbench master regression suite
```

---

## 5. How to Run Regressions & Synthesis

### Running All Simulations in Batch Mode
```powershell
powershell -ExecutionPolicy Bypass -File "./scripts/run_all_regressions.ps1"
```

### Running Cadence Genus Synthesis
```bash
genus -f ./scripts/synth_genus.tcl
```
