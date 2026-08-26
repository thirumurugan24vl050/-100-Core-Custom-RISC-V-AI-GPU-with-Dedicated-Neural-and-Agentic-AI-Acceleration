# 100-Core RISC-V AI GPU — Project Status & Evidence Tracker
## Production V1 Baseline (Architecture Baseline v1.0)

> **Authoritative Evidence Policy**:
> - `PLANNED`: Item defined in architecture / verification plan, work pending.
> - `IN_PROGRESS`: Active RTL implementation or simulation in progress.
> - `VERIFIED`: Simulation / synthesis executed on current RTL revision with logged proof.
> - `STALE`: Module was previously verified, but downstream RTL modifications require re-verification.
> - `UNVERIFIED`: RTL exists but has not completed formal signoff.
> - `BLOCKED`: Prerequisite stage is incomplete.
>
> *Rule: Any RTL change invalidates downstream simulation, coverage, and synthesis evidence, reverting status to STALE until re-run.*

---

## 1. Subsystem Implementation & Verification Status

| Subsystem / Milestone | Target RTL Module(s) | Verification Target | Status | Last Evidence | Notes |
|---|---|---|---|---|---|
| **PACKAGE** | `riscv_ai_gpu_pkg.sv` | Package elaboration | `IN_PROGRESS` | 2026-08-21 | V1 types, constants, flit structs frozen |
| **CORE — RV32I / RV32IM** | `riscv_ai_core.sv`, `core_scalar_alu.sv`, `core_decode_unit.sv`, `core_fetch_unit.sv`, `core_regfile.sv` | `tb_riscv_ai_core` | `PLANNED` | — | 37 base + 8 RV32M instructions |
| **CORE — 4-Warp SIMT** | `core_warp_scheduler.sv`, `core_reconvergence_stack.sv`, `core_lsu.sv` | `tb_riscv_ai_core` | `PLANNED` | — | 4 warps, divergence stack, SPAD LSU |
| **CORE — 256b SIMD** | `core_vector_unit.sv` | `tb_riscv_ai_core` | `PLANNED` | — | INT8 (32 ops), INT4 (64 ops), FP16 (16 ops), INT32 (8 ops) |
| **NMU — 8×8 INT8 Engine** | `neural_systolic_engine_8x8.sv`, `systolic_pe.sv` | `tb_neural_systolic_engine` | `PLANNED` | — | Weight-stationary GEMM (64 PEs) |
| **NMU — Post-Processing** | `neural_postproc_unit.sv` | `tb_neural_postproc` | `PLANNED` | — | ReLU, GELU, Sigmoid, RMSNorm (LUT + 2× NR) |
| **NMU — Softmax Unit** | `neural_softmax_unit.sv` | `tb_neural_softmax` | `PLANNED` | — | 8-lane online streaming softmax |
| **CLUSTER — Scratchpad** | `cluster_scratchpad_sram.sv` | `tb_cluster_scratchpad` | `PLANNED` | — | 64KB (8 banks $\times$ 8KB), crossbar arbitration |
| **CLUSTER — Barrier Sync** | `cluster_barrier_sync.sv` | `tb_cluster_barrier` | `PLANNED` | — | 40-warp barrier generation & arrival |
| **CLUSTER — Top Integration**| `ai_gpu_cluster.sv` | `tb_riscv_ai_gpu_top` | `PLANNED` | — | 10 cores + SPAD + NMU + Barrier |
| **NoC — 5-Port Router** | `noc_router_5port.sv` | `tb_noc_router_5port` | `PLANNED` | — | 160-bit flits, 3 VCs, XY DOR, credit flow |
| **NoC — 10×10 Mesh Fabric** | `noc_mesh_2d_10x10.sv`, `noc_interface_adapter.sv` | `tb_noc_mesh_10x10` | `PLANNED` | — | 100-router 2D mesh structural interconnect |
| **MEMORY — Buffer & Gateway**| `global_buffer.sv`, `memory_gateway.sv` | `tb_riscv_ai_gpu_top` | `PLANNED` | — | 4MB distributed SRAM (16 banks $\times$ 256KB) |
| **MEMORY — 512b DMA** | `axi_dma_controller.sv` | `tb_axi_dma_controller` | `PLANNED` | — | 512-bit scatter-gather AXI master |
| **AGENTIC — DAG Scheduler** | `agent_dag_scheduler.sv` | `tb_agent_dag_scheduler` | `PLANNED` | — | 64-node task DAG, 8 priority levels |
| **AGENTIC — KV Manager** | `paged_kv_cache_mgr.sv` | `tb_paged_kv_cache_mgr` | `PLANNED` | — | 1024 physical pages, refcounting |
| **AGENTIC — Coprocessor Top**| `agentic_coprocessor_top.sv`, `agent_token_router.sv` | `tb_agentic_coprocessor` | `PLANNED` | — | Agent integration subsystem |
| **FULL CHIP SoC** | `riscv_ai_gpu_top.sv` | `tb_riscv_ai_gpu_top` | `PLANNED` | — | 100-core full chip integration (TC01..TC20) |
| **COVERAGE CLOSURE (IMC)** | All Production RTL | 13 TB Regression Suite | `PLANNED` | — | 100% target across all 6 metrics |
| **GENUS SYNTHESIS** | All Production RTL | Gate Netlist Generation | `PLANNED` | — | 90nm GPDK, 1.0 GHz target |
| **LEC SIGNOFF** | RTL vs Netlist | Conformal / LEC | `PLANNED` | — | 0 unmapped/non-equivalent points |
| **STA (TEMPUS)** | Synthesized Netlist | Multi-corner STA | `BLOCKED` | — | Hard signoff: WNS $\ge 0$, TNS $= 0$ |
| **PHYSICAL DESIGN (INNOVUS)**| Synthesized Netlist | Floorplan, CTS, P&R | `BLOCKED` | — | 10×10 floorplan, H-Tree CTS |
| **PHYSICAL SIGNOFF** | GDSII Database | Pegasus / PVS / DRC / LVS | `BLOCKED` | — | 0 DRC/LVS, clean EM/IR |

---

## 2. File Classification & Cleanup Log

| RTL File | Classification | Status in V1 | Action / Justification |
|---|---|---|---|
| `rtl/agentic/agent_tree_search_engine.sv` | Out-of-Scope (Research) | EXCLUDED | MCTS is an optional research extension; excluded from V1 signoff |
| `rtl/core/core_lsu_dcache.sv` | Superseded | EXCLUDED | Replaced by explicit scratchpad LSU `core_lsu.sv` |
| `rtl/memory/l2_cache_bank.sv` | Out-of-Scope | EXCLUDED | V1 uses explicit distributed SRAM `global_buffer.sv`, not coherent L2 |
| `rtl/memory/l2_directory_ctrl.sv` | Out-of-Scope | EXCLUDED | V1 has no directory coherence hardware |
| `rtl/neural/neural_activation_unit.sv` | Replaced | EXCLUDED | Renamed/replaced by `neural_postproc_unit.sv` (includes RMSNorm) |
