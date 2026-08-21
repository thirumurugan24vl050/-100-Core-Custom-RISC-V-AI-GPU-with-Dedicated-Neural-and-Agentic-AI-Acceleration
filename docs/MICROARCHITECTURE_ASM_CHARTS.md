# Microarchitecture Specification & Algorithmic State Machine (ASM) Charts
## 100-Core Custom RISC-V AI GPU (Many-Core Accelerator Prototype)

---

## 1. Executive Summary & Control-Datapath Partitioning
This document provides the formal microarchitectural state diagrams, Algorithmic State Machine (ASM) charts, cycle-accurate timing contracts, and datapath-to-control interfaces for all finite state machines in the 100-Core RISC-V AI GPU.

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

## 2. Core Subsystem ASM Charts (Level 1)

### 2.1 Core Fetch Unit (`core_fetch_unit.sv`)
The Fetch Unit manages instruction pointers for 4 concurrent warps with branch redirection and cache line fetch buffering.

```
       +---------------------------------------------+
       |                 STATE_RESET                 |
       |  - Initialize all Warp PCs to reset_vector  |
       |  - Clear Fetch Valid Flags                  |
       +---------------------------------------------+
                              |
                              | (rst_n == 1)
                              v
       +---------------------------------------------+
+----> |                 STATE_ARBITRATE             | <----+
|      |  - Select active Warp ID (Round-Robin)      |      |
|      |  - Check if Warp is Ready (not stalled)     |      |
|      +---------------------------------------------+      |
|                             |                             |
|                             | [Warp Ready]                |
|                             v                             |
|      +---------------------------------------------+      |
|      |                 STATE_ISSUE_REQ             |      |
|      |  - Issue I-Cache Request Address (Warp PC)  |      |
|      |  - Assert icache_req_val = 1                |      |
|      +---------------------------------------------+      |
|                             |                             |
|            +----------------+----------------+            |
|            |                                 |            |
|    [icache_ready == 1]              [branch_redirect == 1]|
|            v                                 v            |
|  +-----------------------+         +--------------------+ |
|  |    STATE_RECEIVE_INSTR|         | STATE_FLUSH_BRANCH | |
|  | - Capture Instruction |         | - Update Warp PC   | |
|  | - Increment PC by 4   |         | - Flush Pipeline   |-+
|  | - Forward to Decode   |         +--------------------+
|  +-----------------------+
|            |
+------------+
```

#### State Transition Table
| Current State | Condition | Next State | Outputs Asserted |
| :--- | :--- | :--- | :--- |
| `RESET` | `rst_n == 0` | `RESET` | `icache_req_val = 0`, `pc_out = 0` |
| `RESET` | `rst_n == 1` | `ARBITRATE` | `icache_req_val = 0` |
| `ARBITRATE` | `warp_ready[w] == 1` | `ISSUE_REQ` | `icache_req_addr = warp_pc[w]` |
| `ARBITRATE` | `all_warps_stalled` | `ARBITRATE` | `icache_req_val = 0` |
| `ISSUE_REQ` | `branch_redirect` | `FLUSH_BRANCH`| `warp_pc[w] = branch_target` |
| `ISSUE_REQ` | `icache_ready` | `RECEIVE_INSTR` | `icache_req_val = 1` |
| `RECEIVE_INSTR`| Unconditional | `ARBITRATE` | `instr_valid = 1`, `warp_pc += 4` |
| `FLUSH_BRANCH` | Unconditional | `ARBITRATE` | `pipeline_flush = 1` |

---

### 2.2 Core Warp Scheduler & Scoreboard (`core_warp_scheduler.sv`)
Manages 4-warp hardware multithreading with single-cycle zero-overhead context switching.

```
       +---------------------------------------------+
       |                 STATE_IDLE                  |
       |  - Warp Status = WAITING_ACTIVE             |
       |  - Clear Register Scoreboard Busy Bits      |
       +---------------------------------------------+
                              |
                              | [warps_active > 0]
                              v
       +---------------------------------------------+
+----> |             STATE_EVAL_READINESS            |
|      |  - Check Scoreboard: RAW / WAW Hazards      |
|      |  - Check Barrier Stall Flag                 |
|      |  - Check Execution Unit Availability        |
|      +---------------------------------------------+
|                             |
|          +------------------+------------------+
|          |                                     |
|   [Candidates Found]                   [All Warps Stalled]
|          v                                     v
|  +-----------------------+           +--------------------+
|  |    STATE_SELECT_WARP  |           | STATE_STALL_CYCLES |
|  | - Priority / RR Arbiter|          | - Assert NOP to ID |
|  | - Select best Warp ID |           | - Wait 1 cycle     |--+
|  +-----------------------+           +--------------------+  |
|          |                                                   |
|          v                                                   |
|  +-----------------------+                                   |
|  |    STATE_DISPATCH     |                                   |
|  | - Assert issue_valid  |                                   |
|  | - Mark Dest Reg BUSY  |                                   |
|  +-----------------------+                                   |
|          |                                                   |
+----------+---------------------------------------------------+
```

---

### 2.3 Core LSU & L1 Data Cache (`core_lsu_dcache.sv`)
Handles scalar 32-bit and vector 256-bit memory operations, scratchpad bank routing, and L1 cache line fills.

```
       +---------------------------------------------+
       |                  STATE_IDLE                 |
       |  - Await load/store instruction from Decode |
       |  - lsu_ready = 1                            |
       +---------------------------------------------+
                              |
                              | [lsu_req_val == 1]
                              v
       +---------------------------------------------+
       |               STATE_ADDR_DECODE             |
       |  - Check Target Address Range:              |
       |    * 0x1000_0000..0x1000_FFFF: Scratchpad   |
       |    * Else: L1 Data Cache                    |
       +---------------------------------------------+
                              |
              +---------------+---------------+
              |                               |
       [is_scratchpad]                 [is_dcache]
              v                               v
    +-------------------+           +-------------------+
    | STATE_SPAD_ACCESS |           | STATE_TAG_LOOKUP  |
    | - Route to Bank   |           | - Compare Tag     |
    | - Spad Ack        |           +-------------------+
    +-------------------+                     |
              |                   +-----------+-----------+
              |                   |                       |
              |             [Tag Match: HIT]      [Tag Mismatch: MISS]
              |                   v                       v
              |         +-------------------+   +-------------------+
              |         | STATE_CACHE_HIT   |   | STATE_L2_REFILL   |
              |         | - Read/Write Word |   | - Issue L2 Read   |
              |         | - Complete LSU Op |   | - Refill Line     |
              |         +-------------------+   | - Update Tag      |
              |                   |             +-------------------+
              |                   |                       |
              +-------------------+-----------------------+
                                  |
                                  v
                        +-------------------+
                        |  STATE_WRITEBACK  |
                        | - Assert lsu_done |
                        | - Write Regfile   |
                        +-------------------+
```

---

## 3. Neural Accelerator ASM Charts (Level 2)

### 3.1 8x8 Systolic GEMM Engine (`neural_systolic_engine_8x8.sv`)

```
       +---------------------------------------------+
       |                 STATE_IDLE                  |
       |  - engine_ready = 1                         |
       |  - PEs clear accumulation registers         |
       +---------------------------------------------+
                              |
                              | [start_gemm == 1]
                              v
       +---------------------------------------------+
       |              STATE_LOAD_WEIGHTS             |
       |  - Shift 8x8 weight matrix into PEs         |
       |  - Latch weights into stationary registers  |
       |  - Duration: 8 clock cycles                 |
       +---------------------------------------------+
                              |
                              | [weights_loaded]
                              v
       +---------------------------------------------+
+----> |             STATE_STREAM_COMPUTE            |
|      |  - Skew input activation rows (0 to 7 cycles)|
|      |  - Propagate activations horizontally (East)|
|      |  - Accumulate MAC products vertically (South)|
|      +---------------------------------------------+
|                             |
|                             | [compute_cycle_count == 24]
|                             v
|      +---------------------------------------------+
|      |              STATE_DRAIN_ACCUM              |
|      |  - Read out 8 columns of 32-bit partial sums|
|      |  - Stream results to Scratchpad / Vector RF |
|      |  - Assert engine_done = 1                   |
|      +---------------------------------------------+
|                             |
+-----------------------------+
```

---

### 3.2 8-Lane Online Softmax Unit (`neural_softmax_unit.sv`)
Calculates $y_i = \frac{e^{x_i - \max(X)}}{\sum e^{x_j - \max(X)}}$ in a streaming 5-stage pipeline.

```
       +---------------------------------------------+
       |                 STATE_IDLE                  |
       |  - Wait for softmax_req_val                 |
       +---------------------------------------------+
                              |
                              | [req_val == 1]
                              v
       +---------------------------------------------+
       |              STATE_PASS1_FIND_MAX           |
       |  - Compare 8 input lanes via reduction tree |
       |  - Register maximum value: X_max            |
       +---------------------------------------------+
                              |
                              v
       +---------------------------------------------+
       |             STATE_PASS2_EXP_SUM             |
       |  - Shift inputs: diff[i] = x[i] - X_max     |
       |  - Approximate exponent: exp[i] = 2^(diff/ln2)
       |  - Compute running sum: Sum_exp = sum(exp[i])
       +---------------------------------------------+
                              |
                              v
       +---------------------------------------------+
       |             STATE_PASS3_NORMALIZE           |
       |  - Fixed-point reciprocal multiplication:   |
       |    prob[i] = (exp[i] * 65536) / Sum_exp     |
       |  - Assert softmax_done = 1                  |
       +---------------------------------------------+
                              |
                              v
       +---------------------------------------------+
       |                 STATE_OUTPUT                |
       |  - Stream 8 probability lanes to regfile    |
       +---------------------------------------------+
```

---

## 4. Agentic AI Coprocessor ASM Charts (Level 3)

### 4.1 64-Node Hardware Task DAG Scheduler (`agent_dag_scheduler.sv`)

```
       +---------------------------------------------+
       |                 STATE_IDLE                  |
       |  - Await DAG insert / fire command          |
       +---------------------------------------------+
                              |
              +---------------+---------------+
              |                               |
       [op == DAG_INSERT]              [op == DAG_FIRE / POLL]
              v                               v
    +-------------------+           +-------------------+
    | STATE_INSERT_NODE |           | STATE_EVAL_BITMASK|
    | - Write Node Entry|           | - Parallel Mask:  |
    | - Set Dep_Mask    |           |   ready = valid & |
    | - Mark valid = 1  |           |   !(dep & ~done)  |
    +-------------------+           +-------------------+
              |                               |
              |                               v
              |                     +-------------------+
              |                     | STATE_PRIO_SELECT |
              |                     | - 8-Level Priority|
              |                     |   Encoder chooses |
              |                     |   highest task_id |
              |                     +-------------------+
              |                               |
              |                     +---------+---------+
              |                     |                   |
              |              [Task Available]    [No Task Ready]
              |                     v                   v
              |             +---------------+   +---------------+
              |             | STATE_DISPATCH|   |  STATE_IDLE   |
              |             | - Output ID   |   +---------------+
              |             | - running = 1 |
              |             | - dispatch=1  |
              |             +---------------+
              |                     |
              +---------------------+
```

---

### 4.2 1024-Page Paged KV-Cache Manager (`paged_kv_cache_mgr.sv`)

```
       +---------------------------------------------+
       |                 STATE_IDLE                  |
       |  - Await KV_ALLOC, KV_FREE, or KV_LOOKUP    |
       +---------------------------------------------+
                              |
              +---------------+---------------+
              |               |               |
       [op == ALLOC]   [op == LOOKUP]  [op == FREE]
              v               v               v
    +-------------------+ +---------+ +-------------------+
    | STATE_BITMAP_SCAN | |STATE_   | | STATE_RECLAIM     |
    | - Priority encoder| | LOOKUP  | | - Ref_count -= 1  |
    |   finds 1st free  | | - Search| | - If ref == 0:    |
    |   bit in 1024-bit | |   Page  | |   Clear bitmap bit|
    |   allocation mask | |   Table | | - Assert free_ack |
    +-------------------+ | - Assert| +-------------------+
              |           |   hit   |           |
              v           +---------+           |
    +-------------------+     |                 |
    | STATE_PAGE_ASSIGN |     |                 |
    | - Set bitmap[page]|     |                 |
    | - ref_count = 1   |     |                 |
    | - Output page_id  |     |                 |
    +-------------------+     |                 |
              |               |                 |
              +---------------+-----------------+
                              |
                              v
                        +-----------+
                        |STATE_DONE |
                        +-----------+
```

---

## 5. Interconnect & Memory Subsystem ASM Charts

### 5.1 5-Port Virtual Channel NoC Router (`noc_router_5port.sv`)

```
       +---------------------------------------------+
       |              STATE_INGRESS_RX               |
       |  - Latch flits from 5 input ports into FIFOs|
       |  - Check FIFO credit flow-control counters  |
       +---------------------------------------------+
                              |
                              v
       +---------------------------------------------+
       |             STATE_ROUTE_COMPUTE             |
       |  - For each non-empty FIFO head:            |
       |    dx = dest_x - current_x                  |
       |    dy = dest_y - current_y                  |
       |    If (dx > 0) Port = EAST                  |
       |    If (dx < 0) Port = WEST                  |
       |    If (dx == 0 && dy > 0) Port = SOUTH      |
       |    If (dx == 0 && dy < 0) Port = NORTH      |
       |    If (dx == 0 && dy == 0) Port = LOCAL     |
       +---------------------------------------------+
                              |
                              v
       +---------------------------------------------+
       |             STATE_VC_ARBITRATION            |
       |  - Build 5x5 Request Matrix                 |
       |  - Priority Round-Robin per output port     |
       |  - Check downstream out_ready credits       |
       +---------------------------------------------+
                              |
                              v
       +---------------------------------------------+
       |            STATE_CROSSBAR_SWITCH            |
       |  - Grant inputs connect to requested outputs|
       |  - Forward flit payload across links        |
       |  - Decrement FIFO depth counter             |
       +---------------------------------------------+
```

---

### 5.2 Streaming DMA Master Controller (`axi_dma_controller.sv`)

```
       +---------------------------------------------+
       |                 STATE_IDLE                  |
       |  - dma_ready = 1                            |
       |  - Await start_dma command from Host CSR    |
       +---------------------------------------------+
                              |
                              | [dma_start == 1]
                              v
       +---------------------------------------------+
       |            STATE_FETCH_DESCRIPTOR           |
       |  - Read Source Address, Dest Address, Length|
       |  - Compute total 512-bit burst beats count  |
       +---------------------------------------------+
                              |
                              v
       +---------------------------------------------+
+----> |             STATE_BURST_READ_REQ            |
|      |  - Issue AXI5 512-bit Read Address (AR)     |
|      |  - Stream beats into internal Elastic FIFO  |
|      +---------------------------------------------+
|                             |
|                             | [FIFO beat ready]
|                             v
|      +---------------------------------------------+
|      |             STATE_BURST_WRITE_REQ           |
|      |  - Issue AXI5 512-bit Write Address (AW)    |
|      |  - Write 512-bit Data Beat into L2 Bank     |
|      |  - Decrement remaining transfer bytes       |
|      +---------------------------------------------+
|                             |
|            +----------------+----------------+
|            |                                 |
|    [bytes_remaining > 0]             [bytes_remaining == 0]
|            |                                 v
+------------+                       +-------------------+
                                     |  STATE_COMPLETION |
                                     | - Assert dma_done |
                                     | - Trigger Host IRQ|
                                     +-------------------+
```
