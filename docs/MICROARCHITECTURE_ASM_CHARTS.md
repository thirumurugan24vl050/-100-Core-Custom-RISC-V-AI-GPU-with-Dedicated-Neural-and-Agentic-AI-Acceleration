# Microarchitecture Specification & Algorithmic State Machine (ASM) Charts
## 100-Core Custom RISC-V SIMT AI GPU (Architecture Baseline v1.0)

---

## 1. Executive Summary & Control-Datapath Partitioning

This document provides formal microarchitectural state diagrams, Algorithmic State Machine (ASM) charts, cycle-accurate timing contracts, and datapath-to-control interfaces for all finite state machines in the 100-Core RISC-V SIMT AI GPU.

```
+--------------------------------------------------------------------------------------------------+
|                                    100-CORE RISC-V AI GPU TOP                                    |
|                                                                                                  |
|  +--------------------------------+  +--------------------------------+  +--------------------+  |
|  |     GLOBAL AGENTIC AI ENGINE   |  |   HIGH-SPEED AXI5 / DMA ENGINE |  |   GLOBAL PLL /     |  |
|  |  * Dynamic Task DAG Scheduler  |  |  * 512-bit Host Memory Bus     |  |   RESET CONTROLLER |  |
|  |  * Paged KV-Cache Directory    |  |  * 512-bit Scatter-Gather Descs|  |  * Synchronous     |  |
|  |  * Priority Token Router       |  |  * 64-bit Physical Addressing  |  |    De-assertion    |  |
|  |  * Hardware Event Dispatcher   |  +--------------------------------+  +--------------------+  |
|  +--------------------------------+                                                              |
|                                                                                                  |
|  +--------------------------------------------------------------------------------------------+  |
|  |                     10x10 2D-MESH NETWORK-ON-CHIP (NoC) INTERCONNECT                       |  |
|  |     (160-bit Flit, 32b Header + 128b Payload, 3 Virtual Channels, Dimension-Order XY)      |  |
|  +--------------------------------------------------------------------------------------------+  |
|         |                  |                  |                  |                  |            |
|  +--------------+  +--------------+  +--------------+  +--------------+  +--------------+        |
|  |  CLUSTER 0   |  |  CLUSTER 1   |  |  CLUSTER 2   |  |  CLUSTER 3   |  |  CLUSTER 9   | ...    |
|  | (Cores 00-09)|  | (Cores 10-19)|  | (Cores 20-29)|  | (Cores 30-39)|  | (Cores 90-99)|        |
|  | * 10 RV Cores|  | * 10 RV Cores|  | * 10 RV Cores|  | * 10 RV Cores|  | * 10 RV Cores|        |
|  | * Neural 8x8 |  | * Neural 8x8 |  | * Neural 8x8 |  | * Neural 8x8 |  | * Neural 8x8 |        |
|  | * GELU/Softmx|  | * GELU/Softmx|  | * GELU/Softmx|  | * GELU/Softmx|  | * GELU/Softmx|        |
|  | * 64KB SPAD  |  | * 64KB SPAD  |  | * 64KB SPAD  |  | * 64KB SPAD  |  | * 64KB SPAD  |        |
|  | * Barrier Gen|  | * Barrier Gen|  | * Barrier Gen|  | * Barrier Gen|  | * Barrier Gen|        |
|  +--------------+  +--------------+  +--------------+  +--------------+  +--------------+        |
|                                                                                                  |
|  +--------------------------------------------------------------------------------------------+  |
|  |             4MB DISTRIBUTED GLOBAL SRAM / SHARED AI BUFFER (NON-COHERENT V1)               |  |
|  |                     (16 Banks x 256KB = 4MB, Explicit Software Sync)                       |  |
|  +--------------------------------------------------------------------------------------------+  |
+--------------------------------------------------------------------------------------------------+
```

---

## 2. Core Subsystem ASM Charts (Tile Level)

### 2.1 Core Fetch & Warp Issue Unit (`core_fetch_unit.sv`)
Manages instruction pointers for 4 concurrent warps with branch redirection and zero-bubble switching.

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

---

### 2.2 Core Warp Scheduler & Scoreboard (`core_warp_scheduler.sv`)
Tracks 4 architectural warps ($W_0..W_3$) across 7 authoritative warp states: `WARP_READY`, `WARP_RUNNING`, `WARP_WAIT_MEM`, `WARP_WAIT_NMU`, `WARP_WAIT_BARRIER`, `WARP_WAIT_AGENT`, `WARP_DONE`. (Branch divergence is handled separately via the 8-entry reconvergence stack in `core_reconvergence_stack.sv`).

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
|      |  - Check Barrier Stall & Tensor Stall Flags |
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

### 2.3 Core LSU & Scratchpad / NoC Interface (`core_lsu.sv`)
Handles 32-bit scalar and 256-bit SIMD memory operations, scratchpad bank routing, and 64-bit physical address generation.

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
       |  - Check 64-bit Physical Address Range:     |
       |    * 0x0000_1000_0000..: Local SPAD (64KB)  |
       |    * 0x0000_2000_0000..: Global SRAM (4MB)  |
       |    * 0x0000_8000_0000..: External DRAM (AXI)|
       +---------------------------------------------+
                              |
              +---------------+---------------+
              |                               |
       [is_scratchpad]                 [is_global_sram]
              v                               v
    +-------------------+           +-------------------+
    | STATE_SPAD_ACCESS |           | STATE_NOC_MEM_REQ |
    | - Route to Bank   |           | - Format 160b flit|
    | - SPAD Ack        |           | - Inject to NoC   |
    +-------------------+           +-------------------+
              |                               |
              +---------------+---------------+
                              |
                              v
                    +-------------------+
                    |  STATE_WRITEBACK  |
                    | - Assert lsu_done |
                    | - Write Regfile   |
                    +-------------------+
```

---

## 3. Neural Matrix Unit (NMU) ASM Charts

### 3.1 8x8 Weight-Stationary Systolic GEMM Engine (`neural_systolic_engine_8x8.sv`)

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
|      |  - Stream results to SPAD / Vector RF       |
|      |  - Assert engine_done = 1                   |
|      |  - Broadcast completion tag to release warp |
|      +---------------------------------------------+
|                             |
+-----------------------------+
```

---

## 4. Interconnect & Memory ASM Charts

### 4.1 5-Port Virtual Channel NoC Router (`noc_router_5port.sv`)

```
       +---------------------------------------------+
       |              STATE_INGRESS_RX               |
       |  - Latch 160b flits from 5 input ports      |
       |  - Demux into VC0 (Req), VC1 (Resp), VC2(Ctl)|
       +---------------------------------------------+
                              |
                              v
       +---------------------------------------------+
       |             STATE_ROUTE_COMPUTE             |
       |  - Dimension-Order XY Routing:              |
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
       |  - Priority Round-Robin per output port     |
       |  - Check downstream out_ready credits       |
       +---------------------------------------------+
                              |
                              v
       +---------------------------------------------+
       |            STATE_CROSSBAR_SWITCH            |
       |  - Grant inputs connect to requested outputs|
       |  - Forward 160b flit across physical link   |
       |  - Decrement input FIFO depth counter       |
       +---------------------------------------------+
```

---

### 4.2 512-Bit Scatter-Gather DMA Controller (`axi_dma_controller.sv`)

```
       +---------------------------------------------+
       |                 STATE_IDLE                  |
       |  - dma_ready = 1                            |
       |  - Await start_dma from Host CSR            |
       +---------------------------------------------+
                              |
                              | [dma_start == 1]
                              v
       +---------------------------------------------+
       |            STATE_FETCH_DESCRIPTOR           |
       |  - Read 512-bit descriptor from memory      |
       |  - Parse src_addr[63:0], dst_addr[63:0], len|
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
|      |  - Write 512-bit Data Beat into Global SRAM |
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
                                     | - Check next_desc |
                                     | - Trigger Host IRQ|
                                     +-------------------+
```

---

## 5. Agentic AI Coprocessor ASM Charts

### 5.1 64-Node Hardware Task DAG Scheduler (`agent_dag_scheduler.sv`)

```
       +---------------------------------------------+
       |                 STATE_IDLE                  |
       |  - Await DAG insert / poll command          |
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
              |                     |   Encoder selects |
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
              |             | - dispatch = 1|
              |             +---------------+
              |                     |
              +---------------------+
```

---

### 5.2 1024-Page Paged KV-Cache Manager (`paged_kv_cache_mgr.sv`)

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
