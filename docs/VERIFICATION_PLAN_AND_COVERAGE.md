# Comprehensive Verification Plan & Coverage Specification
## 100-Core Custom RISC-V SIMT AI GPU (Architecture Baseline v1.0 — Production V1 Only)

---

## 1. Verification Strategy & Architecture

The verification environment is designed around a multi-tier, self-checking methodology aligned with the 17-stage verification ladder and Cadence IMC / Verisium signoff standards:
- **Layer 1: Unit Level Verification**: Arithmetic, decoding, vector SIMD, warp scheduling, memory arbitration, routing, and coprocessor units tested against independent mathematical golden models.
- **Layer 2: Cluster Level Verification**: 10-Core multi-core concurrency, 64KB shared scratchpad crossbar contention, systolic GEMM orchestration, and 40-warp barrier generation tracking.
- **Layer 3: SoC Full-Chip Level Verification**: 100-Core global grid, 10x10 NoC XY dimension-order routing, 4MB distributed global buffer, 512-bit DMA burst streaming, and Host CSR control telemetry.

---

## 2. Production V1 Verification Scope

### 2.1 Production RTL Subsystems in Scope
```
rtl/
├── include/
│   └── riscv_ai_gpu_pkg.sv
│
├── core/
│   ├── core_fetch_unit.sv
│   ├── core_decode_unit.sv
│   ├── core_regfile.sv
│   ├── core_scalar_alu.sv
│   ├── core_vector_unit.sv
│   ├── core_warp_scheduler.sv
│   ├── core_lsu.sv
│   ├── core_reconvergence_stack.sv
│   └── riscv_ai_core.sv
│
├── neural/
│   ├── systolic_pe.sv
│   ├── neural_systolic_engine_8x8.sv
│   ├── neural_postproc_unit.sv
│   └── neural_softmax_unit.sv
│
├── cluster/
│   ├── cluster_scratchpad_sram.sv
│   ├── cluster_barrier_sync.sv
│   └── ai_gpu_cluster.sv
│
├── noc/
│   ├── noc_router_5port.sv
│   ├── noc_interface_adapter.sv
│   └── noc_mesh_2d_10x10.sv
│
├── memory/
│   ├── global_buffer.sv
│   ├── memory_gateway.sv
│   └── axi_dma_controller.sv
│
├── agentic/
│   ├── agent_dag_scheduler.sv
│   ├── paged_kv_cache_mgr.sv
│   ├── agent_token_router.sv
│   └── agentic_coprocessor_top.sv
│
└── top/
    └── riscv_ai_gpu_top.sv
```

### 2.2 Explicitly Excluded from Production V1
The following modules and features are research extensions or out-of-scope for V1 signoff:
- `agent_tree_search_engine.sv` (MCTS hardware is an optional research extension)
- `core_lsu_dcache.sv` (replaced by explicit scratchpad LSU `core_lsu.sv`)
- Coherent L1/L2 cache logic (`l2_cache_bank.sv`, `l2_directory_ctrl.sv`)
- FP16/BF16 NMU (V1 NMU is INT8 $\times$ INT8 $\rightarrow$ INT32 only)
- LayerNorm hardware (V1 uses RMSNorm with Newton-Raphson & LUT)
- Unapproved security/firewall hardware
- Unapproved debug hardware

---

## 3. Frozen 13 Verification Environments

To ensure maintainability, testbench count is frozen at **13 verification environments**. One verification environment exists where there is an actual independent verification responsibility:

| # | Testbench Name | Target Module / Subsystem | Scope & Verification Responsibilities | Status |
|---|---|---|---|---|
| 1 | `tb_riscv_ai_core` | `riscv_ai_core` | Complete core subsystem: RV32IM ALU, 256-bit SIMD, 4-warp scheduler, reconvergence stack, LSU, register file | `PLANNED` |
| 2 | `tb_neural_systolic_engine` | `neural_systolic_engine_8x8` | PE array + 8×8 Weight-Stationary NMU vs mathematical GEMM model | `PLANNED` |
| 3 | `tb_neural_postproc` | `neural_postproc_unit` | ReLU, GELU, Sigmoid, and RMSNorm (LUT + 2× Newton-Raphson) | `PLANNED` |
| 4 | `tb_neural_softmax` | `neural_softmax_unit` | 8-lane Online Softmax normalizer & numerical stability | `PLANNED` |
| 5 | `tb_cluster_scratchpad` | `cluster_scratchpad_sram` | 64KB 8-bank scratchpad SRAM + crossbar arbitration & bank conflicts | `PLANNED` |
| 6 | `tb_cluster_barrier` | `cluster_barrier_sync` | 40-warp barrier arrival, generation tracking, and release broadcast | `PLANNED` |
| 7 | `tb_noc_router_5port` | `noc_router_5port` | 5-port router, 160-bit flits, 3 VCs, XY DOR routing, credit flow | `PLANNED` |
| 8 | `tb_noc_mesh_10x10` | `noc_mesh_2d_10x10` | Full 10×10 100-router mesh fabric, multi-hop routing, bisection stress | `PLANNED` |
| 9 | `tb_axi_dma_controller` | `axi_dma_controller` | 512-bit DMA scatter-gather, descriptor engine, AXI streaming bursts | `PLANNED` |
| 10 | `tb_agent_dag_scheduler` | `agent_dag_scheduler` | 64-node task DAG dependency bitmasks, 8 priority queues, preemption | `PLANNED` |
| 11 | `tb_paged_kv_cache_mgr` | `paged_kv_cache_mgr` | 1024-page allocation bitmap, 1-cycle find-free, refcount prefix sharing | `PLANNED` |
| 12 | `tb_agentic_coprocessor` | `agentic_coprocessor_top` | Agent integration: DAG scheduler + KV cache + token router | `PLANNED` |
| 13 | `tb_riscv_ai_gpu_top` | `riscv_ai_gpu_top` | Full 100-core SoC, global buffer, gateways, top integration suite | `PLANNED` |

> **Rule on Testbench Growth**: The testbench set is frozen at 13. Do NOT create duplicate testbenches (e.g. `tb_core_v2`, `tb_noc_test2`). Use Git revisions to manage changes.

---

## 4. Test Case Distribution & Progressive Target

### 4.1 Test Case Target Matrix (~260 Tests Total)

| Verification Area | Directed Tests | Random / Stress Tests | Total Target |
|---|---|---|---|
| RISC-V Core + SIMT | 30 | 20 | 50 |
| SIMD Unit | 12 | 8 | 20 |
| NMU (8×8 Array) | 15 | 10 | 25 |
| Post-Processing (Activations + Softmax) | 15 | 10 | 25 |
| Scratchpad + Barrier | 15 | 10 | 25 |
| NoC Router + 10×10 Mesh | 20 | 15 | 35 |
| DMA + Global Buffer | 15 | 10 | 25 |
| DAG + KV + Agentic Coprocessor | 15 | 10 | 25 |
| Full-Chip SoC | 10 | 20 | 30 |
| **Total Cumulative Target** | **147** | **113** | **260** |

### 4.2 Progressive Verification Phases
1. **Phase 1 (Smoke / Bring-up)**: 20–30 cumulative tests
2. **Phase 2 (Subsystem Core Verification)**: 50–70 cumulative tests
3. **Phase 3 (Cluster & Interconnect Integration)**: 100–120 cumulative tests
4. **Phase 4 (System & Coprocessor Integration)**: 160–180 cumulative tests
5. **Full-Chip Regression & Coverage Closure**: 200–260 cumulative tests + randomized seeds

---

## 5. Coverage Philosophy: "200 Tests $\neq$ 100% Coverage"

Raw test count does not equal coverage. Coverage is determined by what those tests exercise across statements, branches/conditions, toggles, FSMs, and functional crosses.

### The Six 100% Signoff Targets
1. **Overall Verification Coverage**: **100%**
2. **Statement / Code Coverage**: **100%** (All executable RTL portions exercised)
3. **Block Coverage**: **100%** (Every functional block reached)
4. **Expression / Condition Coverage**: **100%** (All decision outcomes and boolean terms exercised)
5. **FSM Coverage**:
   - **State Coverage**: **100%**
   - **Transition Coverage**: **100%**
6. **Toggle Coverage**: **100%** (All signal bits exercised with $0 \rightarrow 1$ and $1 \rightarrow 0$ transitions)

---

## 6. Functional Coverage Specification

SystemVerilog covergroups and crosses are mandatory for signoff across all architectural features:

### 6.1 Required Covergroups
- **RISC-V ISA**: RV32I base instruction classes, RV32M operations (MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU), custom ISA opcodes (`CUSTOM-0`, `CUSTOM-1`).
- **SIMT / Warps**: Warp states (`READY`, `RUNNING`, `WAIT_MEM`, `WAIT_NMU`, `WAIT_BARRIER`, `WAIT_AGENT`, `DONE`), warp selection round-robin, active lane masks, branch divergence events, reconvergence stack depth ($0..8$).
- **SIMD Engine**: Data types (INT8, INT4, FP16, INT32), SIMD arithmetic operations (ADD, SUB, MUL, DOT, MAX, MIN, SHIFT).
- **NMU Systolic Engine**: Matrix dimension sweeps ($1\times1$ to $8\times8$), input activation skews, command queue occupancy ($0..8$).
- **Cluster Memory & Sync**: Scratchpad bank contention (simultaneous accesses to same bank), barrier IDs, barrier participant counts ($1..40$ warps).
- **NoC Fabric**: Ingress/egress directions (North, South, East, West, Local), Virtual Channels (VC0, VC1, VC2), flit types (Head, Body, Tail, Single), network congestion backpressure.
- **Memory & DMA**: DMA transfer directions (Host $\rightarrow$ Buffer, Buffer $\rightarrow$ Host, Buffer $\rightarrow$ SPAD), burst lengths ($1..64$ flits), unaligned transfers.
- **Agentic Engine**: DAG dependency topologies (linear, diamond, tree, cyclic error), DAG priority levels ($0..7$), KV-cache operations (`ALLOC`, `FREE`, `LOOKUP`, `REFCOUNT`), agent event routing flits.
- **Corner Cases & Faults**: FIFO full stalls, credit starvation, boundary addresses, illegal instructions.

### 6.2 Mandatory Functional Crosses
- `SIMD Mode × SIMD Operation`
- `Warp State × Instruction Class`
- `NoC VC × Message Type`
- `NoC Direction × Congestion / Stall`
- `DMA Direction × Burst Length`
- `DAG Priority × Prerequisite Count`
- `KV Cache Operation × Block State`

---

## 7. Clean Full-Chip Integration Test Suite (`tb_riscv_ai_gpu_top`)

The 20 top-level integration tests are strictly defined for V1 production:

| Test ID | Test Name | Description & Verification Objective | Status |
|---|---|---|---|
| **TC01** | Power-on Reset / Default State | Verify reset propagation, register default initialization, and zero active warps | `PLANNED` |
| **TC02** | RV32IM Program Execution | Execute multi-instruction scalar program with arithmetic and branches | `PLANNED` |
| **TC03** | Custom ISA Decode | Validate `CUSTOM-0` and `CUSTOM-1` instruction decoding and execution pipeline | `PLANNED` |
| **TC04** | 100-Core Enumeration | Verify all 100 cores respond to unique `core_id` and `cluster_id` reads | `PLANNED` |
| **TC05** | 400-Warp Context Operation | Initialize and concurrently switch across 4 warps per core (400 warps total) | `PLANNED` |
| **TC06** | SIMD INT8/INT4/FP16/INT32 | Exercise 256-bit SIMD vector execution across all supported data types | `PLANNED` |
| **TC07** | Branch Divergence / Reconvergence | Push/pop split thread masks through 8-entry reconvergence stack | `PLANNED` |
| **TC08** | 8×8 INT8 GEMM | Execute weight-stationary matrix multiply across cluster systolic array | `PLANNED` |
| **TC09** | NMU Multi-Core Arbitration | Concurrent GEMM requests from 10 cores arbitrated by cluster command FIFO | `PLANNED` |
| **TC10** | Scratchpad Bank Contention | Simultaneous bank accesses with crossbar arbitration and stall resolution | `PLANNED` |
| **TC11** | 40-Warp Barrier Synchronization | 40 warps within a cluster reach hardware barrier; release on full arrival | `PLANNED` |
| **TC12** | 10×10 XY NoC Routing | Multi-hop packet transmission from $(0,0)$ to $(9,9)$ via XY DOR | `PLANNED` |
| **TC13** | NoC VC Backpressure | Fill VC buffers to capacity; verify lossless credit backpressure | `PLANNED` |
| **TC14** | Multi-Flit Packet Reconstruction | Transmit Head, Body, and Tail flits; verify intact payload assembly | `PLANNED` |
| **TC15** | Global Buffer Read/Write | Multi-bank concurrent read/write transactions into 4MB global SRAM | `PLANNED` |
| **TC16** | 512-bit DMA Scatter-Gather | DMA block transfer with strided address translation and descriptor parsing | `PLANNED` |
| **TC17** | DMA $\rightarrow$ SPAD + `AI_FENCE` | DMA streaming to cluster scratchpad; enforce memory visibility via fence | `PLANNED` |
| **TC18** | 64-Task DAG Scheduling | Dispatch multi-stage dependency graph; verify readiness evaluation & priority | `PLANNED` |
| **TC19** | KV Alloc/Free/Lookup/Refcount | Manage KV cache physical pages; verify zero-copy sharing and reclaim | `PLANNED` |
| **TC20** | Token/Event Routing + Stress | Concurrent multi-agent flit routing with 100-core randomized compute load | `PLANNED` |

---

## 8. Cadence Incisive / IMC Coverage Closure Workflow

```
       Run Regression
             │
             ▼
        Cadence IMC
             │
             ▼
    Find Coverage Holes
             │
             ▼
   Classify Each Hole
   ├── Real Untested Logic ──► Add Targeted Test/Stimulus ──► Re-run
   └── Structurally Unreachable Logic ──► Formally Justify & Document
             │
             ▼
    Repeat until 100%
```

> [!CAUTION]
> **No Blind Exclusions**: Coverage holes must NEVER be eliminated by turning off scoring, blindly adding exclusions, forcing bins, or removing valid RTL. Every exclusion requires formal architectural justification and documentation.

---

## 9. Official Coverage Signoff Table

| Metric | Target | Final Signoff Requirement | Status |
|---|---|---|---|
| **Overall Verification Coverage** | **100%** | Comprehensive signoff across all scoring metrics | `PLANNED` |
| **Block Coverage** | **100%** | All production RTL functional blocks reached | `PLANNED` |
| **Statement / Code Coverage** | **100%** | All executable lines executed | `PLANNED` |
| **Expression / Condition Coverage** | **100%** | All branch conditions evaluated true and false | `PLANNED` |
| **Toggle Coverage** | **100%** | All state/data nets toggled $0 \rightarrow 1$ and $1 \rightarrow 0$ | `PLANNED` |
| **FSM State Coverage** | **100%** | All states in all control FSMs entered | `PLANNED` |
| **FSM Transition Coverage** | **100%** | All valid transitions in all control FSMs taken | `PLANNED` |
| **Functional Coverage** | **100%** | All planned covergroups and crosses fully hit | `PLANNED` |
| **Applicable SVA Coverage** | **100%** | All concurrent assertions active and covered | `PLANNED` |
| **Assertion Failures** | **0** | Zero assertion violations allowed | `PLANNED` |
| **Unresolved Coverage Holes** | **0** | All unhit bins analyzed, closed, or formally justified | `PLANNED` |

---

## 10. Evidence State Policy

All verification and implementation evidence must be tagged with one of the following authoritative states:
- `PLANNED`: Item is defined in architecture/verification plan but execution has not begun.
- `IN_PROGRESS`: Active development/simulation is underway.
- `VERIFIED`: Simulation/synthesis has executed on the current RTL revision with logged proof.
- `STALE`: Module was previously verified, but subsequent RTL modifications require re-verification.
- `UNVERIFIED`: RTL exists but has not undergone formal verification.
- `BLOCKED`: Prerequisite stage is incomplete or missing dependencies.
