# Bidirectional Engineering Traceability Matrix

| Requirement ID | Feature Description | Architecture Component | Microarchitecture Module | RTL File | Testbench | Verification Evidence |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **REQ-CORE-01** | RV32IM Base Scalar Pipeline | RISC-V Compute Core | `core_scalar_alu`, `core_decode_unit`, `core_regfile` | `rtl/core/riscv_ai_core.sv` | `tb_riscv_ai_core.sv` | Verified in Test 1 & 2 (ALU + Mul) |
| **REQ-CORE-02** | 4-Warp Latency Hiding Multithreading | Multi-Warp Scheduler | `core_warp_scheduler` | `rtl/core/core_warp_scheduler.sv` | `tb_riscv_ai_core.sv` | Verified in Test 1 (Warp context preservation) |
| **REQ-CORE-03** | 256-bit Vector SIMD Engine | Vector Unit | `core_vector_unit` | `rtl/core/core_vector_unit.sv` | `tb_riscv_ai_core.sv` | Verified in Test 3 (Dot-product reduction) |
| **REQ-CORE-04** | L1 Data Cache & LSU | Memory Interface | `core_lsu_dcache` | `rtl/core/core_lsu_dcache.sv` | `tb_riscv_ai_core.sv` | Verified in Test 3 (Store/Load cycle) |
| **REQ-NEUR-01** | 8x8 Tensor GEMM Acceleration | Neural Systolic Array | `neural_systolic_engine_8x8`, `systolic_pe` | `rtl/neural/neural_systolic_engine_8x8.sv` | `tb_neural_systolic_engine.sv` | Verified against Mathematical Golden Model |
| **REQ-NEUR-02** | Pipelined Activation Functions (GELU, ReLU, Sigmoid) | Activation Unit | `neural_activation_unit` | `rtl/neural/neural_activation_unit.sv` | `tb_neural_activation.sv` | Verified against Golden Curve Calculations |
| **REQ-NEUR-03** | 8-Lane Online Softmax Unit | Softmax Unit | `neural_softmax_unit` | `rtl/neural/neural_softmax_unit.sv` | `tb_neural_activation.sv` | Verified probability summation and ordering |
| **REQ-AGEN-01** | Hardware Agent Task DAG Scheduler | DAG Scheduler | `agent_dag_scheduler` | `rtl/agentic/agent_dag_scheduler.sv` | `tb_agent_dag_scheduler.sv` | Verified 64-node dependency firing & priority queue |
| **REQ-AGEN-02** | Paged KV-Cache Memory Management | Paged KV Manager | `paged_kv_cache_mgr` | `rtl/agentic/paged_kv_cache_mgr.sv` | `tb_paged_kv_cache_mgr.sv` | Verified 1024-page allocation, lookup, and sharing |
| **REQ-AGEN-03** | MCTS Speculative Tree Search Acceleration | Tree Search Engine | `agent_tree_search_engine` | `rtl/agentic/agent_tree_search_engine.sv` | `tb_agent_tree_search_engine.sv` | Verified UCT score evaluation and branch pruning |
| **REQ-AGEN-04** | Multi-Agent Token & Context Router | Token Router | `agent_token_router` | `rtl/agentic/agent_token_router.sv` | `tb_agentic_coprocessor_top.sv` | Verified NoC packetization and dispatch |
| **REQ-NOC-01** | 5-Port Virtual-Channel NoC Router | 2D-Mesh Router | `noc_router_5port` | `rtl/noc/noc_router_5port.sv` | `tb_noc_router_5port.sv` | Verified XY DOR deadlock-free routing |
| **REQ-CLUS-01** | 10-Core Cluster Integration | Compute Cluster | `ai_gpu_cluster` | `rtl/cluster/ai_gpu_cluster.sv` | `tb_ai_gpu_cluster.sv` | Verified 10-core parallel execution & 64KB SRAM |
| **REQ-MEM-01** | 4MB Distributed Banked L2 Cache | L2 Subsystem | `l2_cache_bank`, `l2_directory_ctrl` | `rtl/memory/l2_cache_bank.sv` | `tb_riscv_ai_gpu_top.sv` | Verified 16-bank line fills & cache hits |
| **REQ-TOP-01** | 100-Core Full Chip Integration | Top-Level ASIC | `riscv_ai_gpu_top` | `rtl/top/riscv_ai_gpu_top.sv` | `tb_riscv_ai_gpu_top.sv` | Verified end-to-end full-chip execution |
