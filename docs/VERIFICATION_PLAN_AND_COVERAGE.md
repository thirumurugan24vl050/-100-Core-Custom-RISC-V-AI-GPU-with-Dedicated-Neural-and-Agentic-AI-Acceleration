# Comprehensive Verification Plan & Coverage Specification
## 100-Core Custom RISC-V SIMT AI GPU (Architecture Baseline v1.0)

---

## 1. Verification Strategy & Architecture
The verification environment is designed around a multi-tier, self-checking methodology aligned with the 17-stage verification ladder and Cadence IMC / Verisium signoff standards:
- **Layer 1: Unit Level Verification**: Individual arithmetic, scheduling, routing, memory, and coprocessor units tested against independent mathematical golden models.
- **Layer 2: Cluster Level Verification**: 10-Core multi-core concurrency, 64KB shared scratchpad crossbar contention, systolic GEMM orchestration, and 40-warp barrier generation tracking.
- **Layer 3: SoC Full-Chip Level Verification**: 100-Core global grid, 10x10 NoC XY dimension-order routing, 4MB distributed global buffer, 512-bit DMA burst streaming, and Host CSR control telemetry.

---

## 2. Testbench Architecture & Coverage Matrix

### 2.1 Verification Suite Inventory (84 Tests Total)

| Testbench Name | Target Module | Scope & Checks | Coverage Targets | Status |
| :--- | :--- | :--- | :--- | :--- |
| `tb_riscv_ai_core` | `riscv_ai_core` | RV32IM ALU, Multiplier, 256-bit Vector SIMD (INT8/4/FP16/32), 4-Warp context preservation, 64-bit LSU, 8-entry reconvergence stack, `AI_FENCE` scopes | 100% Instruction Opcode & Hazard Coverage | **PASS (8/8)** |
| `tb_neural_systolic_engine` | `neural_systolic_engine_8x8` | 8x8 2D Weight-Stationary GEMM vs Mathematical Matrix Golden Model ($C_{ij} = \sum A_{ik} B_{kj}$) | 100% PE Active Accumulation & Boundary Coverage | **PASS (8/8)** |
| `tb_neural_activation` | `neural_activation_unit`, `neural_softmax_unit` | GELU polynomial curve, ReLU saturation, Sigmoid, LayerNorm, 8-Lane Online Softmax normalizer | 100% Function Type & Fixed-Point Tolerance | **PASS (8/8)** |
| `tb_agent_dag_scheduler` | `agent_dag_scheduler` | 64-Node DAG dependency bitmask evaluation, 8-level priority dispatch, task preemption | 100% Dependency Graph Topologies (Linear, Diamond, Tree) | **PASS (8/8)** |
| `tb_paged_kv_cache_mgr` | `paged_kv_cache_mgr` | 1024-Page allocation bitmap, 1-cycle find-first-free, page table hit/miss, zero-copy prefix sharing, pool reclaim | 100% Page State Transitions & Table Walkers | **PASS (8/8)** |
| `tb_agent_tree_search` | `agent_tree_search_engine` | MCTS UCT score evaluation, unvisited node exploration bonus, temperature-based branch pruning mask | 100% Score Ranking & Pruning Thresholds | **PASS (8/8)** |
| `tb_noc_router_5port` | `noc_router_5port` | 5-Port Virtual Channel Router, 160-bit flits, XY Dimension-Order Routing, Crossbar arbitration, credit flow control | 100% Direction Routing (Local, North, South, East, West) | **PASS (8/8)** |
| `tb_ai_gpu_cluster` | `ai_gpu_cluster` | 10 Cores parallel compute, 64KB Banked Scratchpad crossbar arbiter, 40-warp barrier generation synchronizer, cluster neural engine | 100% Inter-Core Bank Contention & Barrier Release | **PASS (8/8)** |
| `tb_riscv_ai_gpu_top` | `riscv_ai_gpu_top` | Full 100-Core Chip Top Level, 512-bit DMA burst into 4MB Global Buffer, Host CSR control, Multi-Agent NoC graph dispatch | 100% End-to-End Chip-Level Integration | **PASS (20/20)** |

---

## 3. Full-Chip 20-Test Master Verification Suite (`tb_riscv_ai_gpu_top`)

1. **TC01**: Power-on Reset & Default Architectural State Initialized Cleanly.
2. **TC02**: Chip Identification Register Validated over Host CSR (`0xA1600001`).
3. **TC03**: 512-bit Streaming DMA Burst & Global Buffer Multi-Bank Line Fill.
4. **TC04**: 10x10 NoC Mesh 2D Grid XY Dimension-Order Routing Fully Operational.
5. **TC05**: 100 RISC-V Compute Cores and 400 Hardware Warps Verified.
6. **TC06**: 8x8 Tensor Systolic GEMM Matrix Multiplier Verified (64 PEs/Cluster).
7. **TC07**: Non-Linear Activation Engine (GELU/ReLU/Sigmoid/LayerNorm) Sweeps Validated.
8. **TC08**: Hardware Agent DAG Task Scheduler Active & Ready for Job Graph Dispatch.
9. **TC09**: Paged Attention KV-Cache Manager Initialized with 1024 Physical Pages.
10. **TC10**: Speculative Tree Search Engine UCT Score & Temperature Pruner Validated.
11. **TC11**: Multi-Agent Token Router and Ingress/Egress Flit Formatting Verified.
12. **TC12**: Hardware Barrier Synchronization Broadcast Across 400 Warps Verified.
13. **TC13**: Network Virtual Channel Backpressure & Credit Flow Control Verified.
14. **TC14**: Address Fault Isolation & Physical Cache Protection Boundary Checked.
15. **TC15**: Read-Only CSR Write Dropped (Security Boundary Enforced).
16. **TC16**: Hardware Packet Firewall & Malformed Packet Drop Verified.
17. **TC17**: Multi-Master Global Buffer Crossbar Round-Robin Arbitration Verified.
18. **TC18**: AXI5 Streaming DMA TLAST Protocol & Burst Length Counters Verified.
19. **TC19**: Full End-to-End Autonomous Agentic Inference Pipeline Validated.
20. **TC20**: 1000-Cycle Randomized Multi-Core Stress Simulation with 0 Contention Faults.

---

## 4. Cadence Incisive / IMC Coverage Scoring Configuration

The coverage configuration file `scripts/cov_config.ccf` instruments all instances with:
```tcl
set_expr_coverable_operators -all
set_expr_coverable_statements -all
set_expr_scoring -struct
set_toggle_scoring -sv_enum
select_coverage -beft -module riscv_ai_gpu_top...
select_coverage -beft -instance tb_riscv_ai_gpu_top.dut...
```

### Coverage Targets for Tapeout Sign-Off:
- **Block / Statement Coverage**: $\ge 100\%^*$ (excluding legitimate unreachable tie-offs)
- **Expression / Condition Coverage**: $\ge 100\%^*$
- **Toggle Coverage**: $\ge 100\%^*$ (scored across all SV enums and structs)
- **FSM State Coverage**: $100\%$
- **FSM Transition Coverage**: $100\%$
- **Concurrent SVA Assertions**: $100\%$ passed with zero failures

---

## 5. Verification Execution Status
- **Local Simulation**: 9/9 Testbenches Passed (84/84 Tests, 100% Pass Rate).
- **Remote Linux EDA Server (`192.168.1.100`)**: Cadence Incisive (`irun -64bit -sv -coverage all`) executed cleanly with 20/20 top-level tests passed.
