# 100-Core Custom RISC-V AI GPU with Dedicated Neural & Agentic AI Acceleration
### *ASIC-Oriented RTL-to-GDSII Implementation (Production V1 Only Baseline)*

[![IEEE 1800-2017](https://img.shields.io/badge/Standard-IEEE%201800--2017%20SystemVerilog-blue.svg)](https://standards.ieee.org/)
[![Verification Status](https://img.shields.io/badge/Verification-13%20TBs%20%7C%20200--260%20Tests%20(PLANNED)-blue.svg)]()
[![EDA Tools](https://img.shields.io/badge/EDA-Cadence%20Genus%20%7C%20Tempus%20%7C%20Innovus-orange.svg)]()
[![Architecture](https://img.shields.io/badge/Architecture-100--Core%20%7C%2010x10%20NoC%20%7C%20Agentic%20AI-purple.svg)]()

---

## 1. Executive Architectural Overview

The **100-Core Custom RISC-V AI GPU** is a domain-specific, massively parallel accelerator combining programmable RISC-V scalar processing, GPU-style SIMT multithreading, packed 256-bit SIMD execution, dedicated 8×8 systolic tensor acceleration, distributed on-chip SRAM movement, and hardware coprocessors for agentic DAG scheduling and paged KV-cache management.

```
+--------------------------------------------------------------------------------------------------+
|                                    100-CORE RISC-V AI GPU TOP                                    |
|                                                                                                  |
|  +--------------------------------+  +--------------------------------+  +--------------------+  |
|  |     GLOBAL AGENTIC AI ENGINE   |  |   HIGH-SPEED AXI5 / DMA ENGINE |  |   CLOCK / RESET    |  |
|  |  * Dynamic Task DAG Scheduler  |  |  * 512-bit Host Memory Bus     |  |   CONTROLLER       |  |
|  |  * Paged KV-Cache Directory    |  |  * Scatter-Gather Streaming    |  |  * Single 1.0 GHz  |  |
|  |  * Priority Token Router       |  |  * 4MB Distributed Buffer      |  |    Sync Domain     |  |
|  +--------------------------------+  +--------------------------------+  +--------------------+  |
|                                                                                                  |
|  +--------------------------------------------------------------------------------------------+  |
|  |                     10x10 2D-MESH NETWORK-ON-CHIP (NoC) INTERCONNECT                       |  |
|  |             (XY Dimension-Order Routing, Credit Flow Control, 3 Virtual Channels)          |  |
|  +--------------------------------------------------------------------------------------------+  |
|         |                  |                  |                  |                  |            |
|  +--------------+  +--------------+  +--------------+  +--------------+  +--------------+        |
|  |  CLUSTER 0   |  |  CLUSTER 1   |  |  CLUSTER 2   |  |  CLUSTER 3   |  |  CLUSTER 9   | ...    |
|  | (Cores 00-09)|  | (Cores 10-19)|  | (Cores 20-29)|  | (Cores 30-39)|  | (Cores 90-99)|        |
|  | * 10 RV Cores|  | * 10 RV Cores|  | * 10 RV Cores|  | * 10 RV Cores|  | * 10 RV Cores|        |
|  | * Neural 8x8 |  | * Neural 8x8 |  | * Neural 8x8 |  | * Neural 8x8 |  | * Neural 8x8 |        |
|  | * RMSNorm/GEL|  | * RMSNorm/GEL|  | * RMSNorm/GEL|  | * RMSNorm/GEL|  | * RMSNorm/GEL|        |
|  | * 64KB SPAD  |  | * 64KB SPAD  |  | * 64KB SPAD  |  | * 64KB SPAD  |  | * 64KB SPAD  |        |
|  | * Warp Sync  |  | * Warp Sync  |  | * Warp Sync  |  | * Warp Sync  |  | * Warp Sync  |        |
|  +--------------+  +--------------+  +--------------+  +--------------+  +--------------+        |
|                                                                                                  |
|  +--------------------------------------------------------------------------------------------+  |
|  |                   4MB DISTRIBUTED GLOBAL BUFFER & MEMORY GATEWAYS                          |  |
|  |                        (16 Banks x 256KB Non-Coherent Distributed SRAM)                    |  |
|  +--------------------------------------------------------------------------------------------+  |
+--------------------------------------------------------------------------------------------------+
```

---

## 2. Production V1 Architecture Scope

### Approved Production RTL (26–27 Modules):
- **`rtl/include/`**: `riscv_ai_gpu_pkg.sv`
- **`rtl/core/`**: `core_fetch_unit.sv`, `core_decode_unit.sv`, `core_regfile.sv`, `core_scalar_alu.sv`, `core_vector_unit.sv`, `core_warp_scheduler.sv`, `core_lsu.sv`, `core_reconvergence_stack.sv`, `riscv_ai_core.sv`
- **`rtl/neural/`**: `systolic_pe.sv`, `neural_systolic_engine_8x8.sv`, `neural_postproc_unit.sv`, `neural_softmax_unit.sv`
- **`rtl/cluster/`**: `cluster_scratchpad_sram.sv`, `cluster_barrier_sync.sv`, `ai_gpu_cluster.sv`
- **`rtl/noc/`**: `noc_router_5port.sv`, `noc_interface_adapter.sv`, `noc_mesh_2d_10x10.sv`
- **`rtl/memory/`**: `global_buffer.sv`, `memory_gateway.sv`, `axi_dma_controller.sv`
- **`rtl/agentic/`**: `agent_dag_scheduler.sv`, `paged_kv_cache_mgr.sv`, `agent_token_router.sv`, `agentic_coprocessor_top.sv`
- **`rtl/top/`**: `riscv_ai_gpu_top.sv`

*Explicitly Excluded from V1*: MCTS tree search engine (`agent_tree_search_engine.sv`), coherent D-cache/L2 (`core_lsu_dcache.sv`, `l2_cache_bank.sv`, `l2_directory_ctrl.sv`), FP16 NMU, LayerNorm, and unapproved debug/security hardware.

---

## 3. Verification Environment & Regression Strategy

```
13 Verification Environments
        ↓
200–260 Cumulative Directed / Constrained-Random Tests
        +
Randomized Regression Seeds
        ↓
20 Dedicated Full-Chip Integration Tests (TC01..TC20)
```

### Frozen 13 Verification Environments

| # | Testbench Name | Verification Target | Status |
|---|---|---|---|
| 1 | `tb_riscv_ai_core` | Complete core subsystem: RV32IM, 256b SIMD, 4 warps, LSU, reconvergence stack | `PLANNED` |
| 2 | `tb_neural_systolic_engine` | PE array + 8×8 Weight-Stationary NMU vs mathematical GEMM model | `PLANNED` |
| 3 | `tb_neural_postproc` | ReLU, GELU, Sigmoid, and RMSNorm (LUT + 2× Newton-Raphson) | `PLANNED` |
| 4 | `tb_neural_softmax` | 8-lane Online Softmax normalizer & numerical stability | `PLANNED` |
| 5 | `tb_cluster_scratchpad` | 64KB 8-bank scratchpad SRAM + crossbar arbitration & bank conflicts | `PLANNED` |
| 6 | `tb_cluster_barrier` | 40-warp barrier arrival, generation tracking, and release broadcast | `PLANNED` |
| 7 | `tb_noc_router_5port` | 5-port router, 160-bit flits, 3 VCs, XY DOR routing, credit flow | `PLANNED` |
| 8 | `tb_noc_mesh_10x10` | Full 10×10 100-router mesh fabric, multi-hop routing, bisection stress | `PLANNED` |
| 9 | `tb_axi_dma_controller` | 512-bit DMA scatter-gather, descriptor engine, AXI streaming bursts | `PLANNED` |
| 10 | `tb_agent_dag_scheduler` | 64-node task DAG dependency bitmasks, 8 priority queues, preemption | `PLANNED` |
| 11 | `tb_paged_kv_cache_mgr` | 1024-page allocation bitmap, 1-cycle find-free, refcount prefix sharing | `PLANNED` |
| 12 | `tb_agentic_coprocessor` | Agent integration: DAG scheduler + KV cache + token router | `PLANNED` |
| 13 | `tb_riscv_ai_gpu_top` | Full 100-core SoC, global buffer, gateways, top integration suite (TC01..TC20) | `PLANNED` |

---

## 4. Cadence ASIC Flow & Signoff Criteria

```
RTL Design ──► Xcelium / IMC ──► Genus Synthesis ──► Conformal LEC ──► Tempus STA ──► Innovus P&R ──► GDSII
```

### Signoff Standards:
- **Coverage**: 100% across Block, Statement, Expression/Condition, Toggle, FSM (State & Transition), Functional Bins/Crosses, and SVA.
- **LEC**: 0 unmapped, non-equivalent, undetectable points or unexplained black boxes.
- **Timing**: Hard signoff $WNS \ge 0\text{ ps}$, $TNS = 0\text{ ps}$, $WHS \ge 0\text{ ps}$, $THS = 0\text{ ps}$, and 0 unconstrained endpoints at target $T_{\text{clk}} = 1.0\text{ ns}$.
- **Physical**: 0 DRC/LVS violations, 0 IR/EM violations, clean GDSII stream-out.

---

## 5. Running the Consistency Audit

```powershell
powershell -ExecutionPolicy Bypass -File "./scripts/check_v1_consistency.ps1"
```
