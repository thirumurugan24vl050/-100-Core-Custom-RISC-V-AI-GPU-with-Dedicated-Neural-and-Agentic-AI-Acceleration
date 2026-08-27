# The Complete Cadence-Centered VLSI Engineering Staircase & Roadmap
## 100-Core Custom RISC-V SIMT AI GPU: Digital Logic to GDSII

---

## 1. Master Engineering Rule
For every architectural concept and hardware module in the 100-Core AI GPU, progress strictly through the 8-step verification cycle:
$$\text{Theory} \longrightarrow \text{RTL Design} \longrightarrow \text{Self-Checking Testbench} \longrightarrow \text{Xcelium Simulation} \longrightarrow \text{IMC Coverage} \longrightarrow \text{Genus Synthesis} \longrightarrow \text{Innovus P\&R} \longrightarrow \text{Sign-Off Evidence}$$

---

## 2. Complete 50-Level Engineering Staircase

```
[01. Linux/Git/Tcl/EDA] ──► [02. Number Systems/Logic] ──► [03. Combinational Logic] ──► [04. Sequential & FSM]
           │
           ▼
[05. Verilog HDL] ───────► [06. Xcelium Simulation] ───► [07. SystemVerilog] ────────► [08. Synthesizable RTL]
           │
           ▼
[09. Width/Signedness] ──► [10. Memories/FIFOs] ────────► [11. C for Hardware] ───────► [12. RISC-V Assembly]
           │
           ▼
[13. Comp Architecture] ─► [14. 5-Stage Pipeline] ─────► [15. RV32I Core] ────────────► [16. RV32IM + CSR/Traps]
           │
           ▼
[17. Run C on RTL] ──────► [18. GPU Architecture] ─────► [19. SIMT/Warp Diverge] ─────► [20. 4-Warp SIMT Core]
           │
           ▼
[21. 256-bit SIMD] ──────► [22. Fixed-Pt/Quantization] ─► [23. Transformer/LLM] ──────► [24. AI MAC/GEMM]
           │
           ▼
[25. Systolic Array] ────► [26. 8x8 NMU Engine] ───────► [27. Bandwidth/Balance] ─────► [28. NoC Mathematics]
           │
           ▼
[29. 5-Port Router] ─────► [30. 10x10 NoC Mesh] ───────► [31. AXI Protocol] ──────────► [32. 512b Scatter DMA]
           │
           ▼
[33. DAG Scheduler] ─────► [34. Paged KV Cache] ───────► [35. Custom RISC-V ISA] ─────► [36. Runtime/MMIO]
           │
           ▼
[37. SVA Assertions] ────► [38. IMC 100% Coverage] ────► [39. JasperGold Formal] ─────► [40. Golden Ref Models]
           │
           ▼
[41. Fault Testing] ─────► [42. Lint / CDC / RDC] ─────► [43. Genus Synthesis] ───────► [44. SDC / Tempus STA]
           │
           ▼
[45. GLS with SDF] ──────► [46. Voltus Power/IR] ──────► [47. Modus DFT / ATPG] ──────► [48. Innovus P&R]
           │
           ▼
[49. Quantus / Pegasus] ─► [50. GDSII Tapeout Signoff]
```

---

### Detailed Stage Breakdown (Level 01 to 50)

#### Phase A: Foundations & Software-to-Hardware Bridge (Levels 01–12)
1. **Level 01: Linux + Git + Tcl + EDA Environment**: Terminal navigation, shell scripting, Git version control, Tcl automation, and standard EDA workspace structure (`rtl/`, `tb/`, `scripts/`, `work/`, `reports/`).
2. **Level 02: Number Systems & Digital Logic**: Binary, Hexadecimal, 2's complement signed representation, fixed-point Q-format, Boolean algebra, De Morgan's laws.
3. **Level 03: Combinational Logic & Arithmetic**: Multiplexers, decoders, priority encoders, ripple-carry/carry-lookahead adders, subtractors, and barrel shifters.
4. **Level 04: Sequential Logic & FSMs**: Latches vs D-Flip-Flops, synchronous registers, shift registers, Moore/Mealy FSMs with illegal-state recovery.
5. **Level 05: Verilog HDL Fundamentals**: Modules, ports, wires, regs, continuous assignments, procedural blocks (`always @(posedge clk)`), blocking vs non-blocking assignments.
6. **Level 06: Simulation & Testbench Architecture (Cadence Xcelium)**: Testbench clock/reset generation, stimulus application, `$display`, `$monitor`, waveform dumping (`.vcd`/`.shm`), delta cycles.
7. **Level 07: SystemVerilog IEEE 1800-2017**: `logic`, `always_comb`, `always_ff`, `always_latch`, `typedef`, `enum`, packed `struct`, `union`, packages, interfaces, generate loops.
8. **Level 08: Synthesizable RTL Methodology**: Translating code into standard cells (logic gates, multiplexers, flip-flops); eliminating inferred latches and multi-driver nets.
9. **Level 09: RTL Width, Signedness & Arithmetic Rules**: Signed vs unsigned propagation, zero/sign extension, truncation, multiplier bit-width growth ($N\text{b} \times M\text{b} \rightarrow (N+M)\text{b}$), and accumulator sizing.
10. **Level 10: Memories, FIFOs & Handshake Protocols**: 1R/1W synchronous SRAM macros, multi-banked scratchpads, valid/ready handshakes, credit-based flow control, synchronous command FIFOs.
11. **Level 11: C Programming for Hardware & Processor Design**: Pointers, bitwise operations, structs, memory layouts, memory-mapped I/O (MMIO), and compilation flow ($C \rightarrow \text{Assembly} \rightarrow \text{Binary}$).
12. **Level 12: RISC-V Assembly & Machine Instruction Encoding**: Instruction decoding (R-type, I-type, S-type, B-type, U-type, J-type), register conventions (`x0`..`x31`), and instruction encodings.

---

#### Phase B: RISC-V Core & SIMT GPU Datapath (Levels 13–20)
13. **Level 13: Computer Architecture Fundamentals**: Datapath and control partitioning, register files, instruction memory, data memory, ALU, branch comparators, CSRs, and memory-mapped I/O.
14. **Level 14: 5-Stage Pipelining & Hazard Resolution**: `IF` $\rightarrow$ `ID` $\rightarrow$ `EX` $\rightarrow$ `MEM` $\rightarrow$ `WB`, RAW data hazards, load-use stalls, ALU-to-ALU forwarding, branch flushes, and multicycle unit bubbles.
15. **Level 15: RISC-V RV32I Base Integer Core**: Complete 32-bit scalar pipelined processor supporting all 37 base integer instructions.
16. **Level 16: RV32IM Core + CSRs / Exceptions / Traps**: Multi-cycle integer hardware multiplier and divider (`MUL`, `MULH`, `DIV`, `REM`), CSR registers (`mstatus`, `mie`, `mtvec`, `mcause`, `mepc`), illegal instruction traps, and misaligned access handlers.
17. **Level 17: Build & Run Compiled C Programs on RTL**: Compiling bare-metal C programs with RISC-V GCC, generating memory initialization files (`.hex`), and simulating execution on RTL.
18. **Level 18: GPU Architecture Principles**: SIMD vs SIMT, threads, warps, lanes, occupancy, warp scheduling, and latency hiding.
19. **Level 19: SIMT Warps, Active Masks & Branch Divergence**: 4 warp contexts per core, 32-lane logical warp width, 32-bit active lane masks, and 8-entry branch reconvergence stacks.
20. **Level 20: 4-Warp RISC-V SIMT Core (`riscv_ai_tile.sv`)**: Integrated SIMT tile with round-robin warp scheduler, decoupled operand collection, and authoritative 7-state warp tracking (`WARP_READY`, `WARP_RUNNING`, `WARP_WAIT_MEM`, `WARP_WAIT_NMU`, `WARP_WAIT_BARRIER`, `WARP_WAIT_AGENT`, `WARP_DONE`). Branch divergence is tracked separately via the 8-entry reconvergence stack.

---

#### Phase C: AI Acceleration, 256-Bit SIMD & Systolic Array (Levels 21–27)
21. **Level 21: 256-Bit Packed SIMD Unit**: 256-bit wide execution engine supporting INT8 (32 ops), INT4 (64 ops), FP16 (16 ops), and INT32 (8 ops).
22. **Level 22: Fixed-Point, Q-Format & Numerical Accuracy**: Quantization, de-quantization, clamping, saturation arithmetic, rounding modes, and INT8 $\times$ INT8 $\rightarrow$ INT32 accumulation.
23. **Level 23: Transformer & LLM Inference Fundamentals**: Self-attention mechanism, Scaled Dot-Product, Softmax, LayerNorm, RMSNorm, GELU, KV Cache paging, prefill vs decode phases.
24. **Level 24: AI MACs, GEMM & Systolic Array Dataflows**: Matrix multiplication algorithms, data reuse strategies, Weight-Stationary vs Output-Stationary vs Activation-Stationary dataflows.
25. **Level 25: 8x8 Systolic Processing Element Array**: 64 PEs arranged in a 2D weight-stationary grid; signed INT8 multiplication with signed 32-bit vertical partial sum accumulation.
26. **Level 26: 8x8 Neural Matrix Unit (NMU) Integration**: Cluster-level NMU with 8-entry command FIFO, input activation skew registers, output de-skew logic, and activation unit (ReLU/GELU/Sigmoid/LayerNorm).
27. **Level 27: Memory Hierarchy, Bandwidth Balance & Arithmetic Intensity**:
    $$\text{Arithmetic Intensity} = \frac{\text{Total Operations (FLOPs/OPs)}}{\text{Total Memory Accesses (Bytes)}}$$
    Calculating required scratchpad bandwidth, NoC bisection bandwidth, and external DRAM throughput to sustain 1.28 TOPS peak compute.

---

#### Phase D: Network-on-Chip, Memory & Agentic Engine (Levels 28–36)
28. **Level 28: NoC Mathematics & Performance Analysis**: Hop count, packet latency, offered load, injection rate, bisection bandwidth, buffer sizing, and head-of-line blocking.
29. **Level 29: 5-Port NoC Router with Virtual Channels**: 5 input/output ports (North, South, East, West, Local), Dimension-Order XY routing, 3 Virtual Channels (`VC0: Request`, `VC1: Response`, `VC2: Agent/Control`), and round-robin switch allocation.
30. **Level 30: 10x10 2D-Mesh NoC Grid**: 100 routers connecting 10 clusters (100 cores), 4MB distributed global buffer, DMA controller, and agentic coprocessor.
31. **Level 31: AXI Protocol Fundamentals**: AXI5/AXI4 5-channel handshaking (`AW`, `W`, `B`, `AR`, `R`), burst transfers (INCR/WRAP), ID ordering, and backpressure flow control.
32. **Level 32: 512-Bit Scatter-Gather DMA Controller**: 512-bit wide AXI master datapath, 512-bit aligned descriptor parsing, 2D strided block transfers, and interrupt generation.
33. **Level 33: Hardware Agentic DAG Task Scheduler**: 64 task entries with 64-bit prerequisite bitmasks, 1-cycle readiness evaluation, and 8-level priority task dispatch over NoC.
34. **Level 34: Paged KV-Cache Manager**: 1024 physical page allocation table, reference-counting engine, zero-copy prefix sharing, and hardware `ALLOC`/`FREE`/`LOOKUP` commands.
35. **Level 35: Custom RISC-V ISA Extension Design**: Opcode assignment (`CUSTOM-0`/`CUSTOM-1`), instruction decode logic, and execution pipelines for `TENS_CFG`, `TENS_LAUNCH`, `TENS_WAIT`, `BARRIER`, `AI_FENCE`, and `AGENT_DAG_INSERT`.
36. **Level 36: Software Runtime & MMIO Driver Layer**: C driver abstractions, custom intrinsic macros (`__builtin_riscv_ai_*`), memory-mapped CSR interfaces, and user-space task dispatchers.

---

#### Phase E: Verification, Synthesis & Cadence ASIC Implementation Flow (Levels 37–50)
37. **Level 37: SystemVerilog Assertions (SVA) & Property-Based Design**: Concurrent assertions for FIFO overflow/underflow, handshake protocol validity, mutual exclusion, and request-to-grant latency bounds.
38. **Level 38: Code & Functional Coverage Closure (Cadence IMC / Verisium)**: Statement, branch, condition, toggle, FSM state/transition, and multi-dimensional cross coverage signoff (100% target).
39. **Level 39: Formal Verification (Cadence JasperGold / Conformal)**: Mathematical proof of safety properties, liveness guarantees, deadlock freedom, and equivalence checking.
40. **Level 40: Independent Behavioral Reference Models**: Python/C++ golden reference models for ALU, 256-bit SIMD, 8x8 GEMM, NoC packet routing, DAG task scheduler, and KV-cache table.
41. **Level 41: Fault Injection & Mutation Testing**: Injecting corrupt packets, dropped credits, invalid opcodes, and memory parity errors to verify hardware fault recovery.
42. **Level 42: Static Lint, CDC & RDC Analysis**: SpyGlass/Hal static lint checks, clock domain crossing synchronizer verification, and reset domain crossing glitch filtering.
43. **Level 43: Logic Synthesis & Technology Mapping (Cadence Genus)**: Mapping RTL to 90nm standard cell libraries, gate optimization, critical path restructuring, and QoR reporting.
44. **Level 44: SDC Timing Constraints & STA (Cadence Tempus)**: `create_clock`, `set_clock_uncertainty`, `set_input_delay`, `set_output_delay`, multi-corner multi-mode (MMMC) setup/hold analysis at 1.0 GHz ($T_{\text{clk}} = 1.0\text{ ns}$).
45. **Level 45: Gate-Level Simulation (GLS) with SDF Back-Annotation**: Simulating synthesized gate-level netlist with Standard Delay Format (SDF) timing across min/typ/max process corners.
46. **Level 46: Power Integrity & IR-Drop Analysis (Cadence Voltus)**: Dynamic switching power, leakage power, static/dynamic IR-drop, and electromigration (EM) limits.
47. **Level 47: Design for Testability (DFT) & ATPG (Cadence Modus)**: Scan chain insertion, scan compression, stuck-at and transition fault ATPG generation, and test pattern validation ($>99\%$ test coverage).
48. **Level 48: Physical Design Implementation (Cadence Innovus)**: Floorplanning (10x10 symmetric grid), Power Distribution Network (PDN on M8/M9), standard cell placement, H-Tree Clock Tree Synthesis (CTS), and Detailed Routing (M1..M7).
49. **Level 49: 3D Parasitic Extraction (Cadence Quantus) & Physical Verification (Pegasus / PVS)**: SPEF generation, DRC (Design Rule Checking), LVS (Layout vs Schematic), and Antenna rule verification.
50. **Level 50: Tapeout Database Generation & GDSII Sign-Off**: Final stream-out, GDSII database generation, multi-corner STA timing closure, and tapeout package delivery.

---

## 3. Cadence Platform Tool & Evidence Matrix

| Project Milestone / Subsystem | Key Concepts Learned | Cadence Tool Invocation | Required Engineering Evidence & Artifacts |
|---|---|---|---|
| **M1: Digital Primitives & ALU** | Gates, 32-bit Adder, MUX, FSM | `xrun -64bit -sv` | Elaboration log, self-checking TB pass |
| **M2: Verilog/SystemVerilog Simulation** | Clock/Reset, Stimulus, Waveforms | `xrun -gui -access +rwc` | Waveform database (`.shm`), simulation log |
| **M3: Memory Macros & FIFOs** | 1R/1W SRAMs, Command FIFOs, SVA | `xrun -assert` | SVA pass log, zero overflow/underflow assertions |
| **M4: 5-Stage RV32I Core** | Pipeline stages, forwarding, stalls | `xrun` + `genus` | 37/37 instruction test pass, initial area report |
| **M5: RV32IM Scalar Core** | Multicycle MUL/DIV, CSRs, Traps | `xrun` (C binary execution) | Bare-metal C program output match, zero traps |
| **M6: 4-Warp SIMT Tile (`riscv_ai_tile.sv`)** | 4 Warps, 32-lane SIMT, Reconvergence | `xrun` (divergence suite) | Branch divergence/reconvergence trace, warp stall stats |
| **M7: 256-bit SIMD Unit** | INT8/4, FP16, INT32 vector ALUs | `xrun` + `genus` | Vector SIMD directed sweep pass, gate-level netlist |
| **M8: 8x8 Systolic NMU Engine** | Weight-stationary 64-PE array, GEMM | `xrun` + Python golden model | Matrix multiplication bit-exact match, 1.28 TOPS peak |
| **M9: 1 Cluster Subsystem** | 10 Cores, 64KB SPAD, Barrier Sync | `xrun` (cluster test suite) | Multi-core barrier release trace, SPAD arbitration log |
| **M10: 10x10 NoC Mesh + DMA + Memory** | 100 Routers, XY DOR, 512b DMA | `xrun` + `genus` | Zero flit drop, 512-bit DMA burst transfer log |
| **M11: Agentic Coprocessor + Top SoC** | 64-Task DAG, 1024-Block KV Cache | `xrun -coverage all` + `imc` | 20/20 top full-chip test pass, IMC coverage database |
| **M12: Verification & ASIC Signoff** | Coverage, Synthesis, STA, P&R, GDSII | `genus` $\rightarrow$ `tempus` $\rightarrow$ `innovus` $\rightarrow$ `voltus` | Synthesized netlist, 1 GHz STA report, clean DRC/LVS, GDSII |

---

## 4. Three-Tier Verification Ladder & 8-Test Learning Protocol

To bridge learning with rigorous tapeout signoff, the verification methodology is structured in three explicit tiers:

```
[TIER 1: Bring-Up Gate]  28 Production RTL Blocks × 8 Unit Tests (224 Local Tests in Isolation)
                                    ↓
[TIER 2: Subsystem Regr] 13 Unified Verification Environments (~260 Formal Tests + Covergroups)
                                    ↓
[TIER 3: Full-Chip SoC]  20 Tapeout Signoff Tests (TC01–TC20 across all 10 Clusters / 100 Cores)
```

### 4.1 Tier 1: Local 8-Test Gate per RTL Block (28 Blocks × 8 = 224 Tests)
Each of the 28 production RTL blocks passes a local 8-test gate in isolation before being merged into its owning verification environment:
- **Normal (2 Tests)**: Nominal, spec-typical operation (e.g., standard arithmetic, nominal FIFO traffic, default barrier arrival).
- **Corner (5 Tests)**: Edge/boundary conditions specific to that block (e.g., FIFO full/empty, min/max dynamic ranges, boundary memory addresses, saturation clamping, active-lane divergence).
- **Ultimate (1 Test)**: Worst-case combined scenario stressing multiple corner conditions simultaneously (e.g., max concurrency + full FIFOs + saturating values at once).

### 4.2 Tier 2: Unified 13 Verification Environments (Doc 7)
The 28 RTL blocks graduate into 13 formal regression environments with functional covergroups, assertions (SVA), and merged IMC coverage scoring.

### 4.3 Tier 3: Full-Chip Tapeout Integration (TC01–TC20)
20 dedicated full-chip test cases exercising all 10 clusters (100 cores), all routers, DMA, and agentic coprocessor for 100% signoff.

