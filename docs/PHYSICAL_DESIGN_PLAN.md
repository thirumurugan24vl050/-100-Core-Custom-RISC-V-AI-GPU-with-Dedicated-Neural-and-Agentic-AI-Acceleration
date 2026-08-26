# Physical Design & Implementation Plan: 100-Core Custom RISC-V AI GPU
## Production V1 Baseline (RTL-to-GDSII Cadence Flow)

---

## 1. ASIC Physical Hierarchy & Floorplanning Strategy

### 1.1 Chip Die Floorplan Partitioning
The chip floorplan is partitioned into a symmetric 10x10 2D array of compute and memory tiles to ensure uniform NoC link delays, balanced clock distribution, and minimal wire congestion.

```
+---------------------------------------------------------------------------------------+
|                                    CHIP TOP BOUNDARY                                  |
|  +---------------------------------------------------------------------------------+  |
|  |                 GLOBAL POWER RING (VDD / VSS Top Metal M8/M9)                   |  |
|  |  +---------------------------+  +---------------------------+                   |  |
|  |  |  HOST CSR & DMA CONTROLLER|  |  GLOBAL AGENTIC ENGINE    |                   |  |
|  |  +---------------------------+  +---------------------------+                   |  |
|  |  +---------------------------------------------------------------------------+  |  |
|  |  |           10x10 2D-MESH NOC FABRIC & COMPUTE CLUSTERS (0 to 9)            |  |  |
|  |  |  [Tile (0,0)] [Tile (0,1)] [Tile (0,2)] ... [Tile (0,9)]                  |  |  |
|  |  |  [Tile (1,0)] [Tile (1,1)] [Tile (1,2)] ... [Tile (1,9)]                  |  |  |
|  |  |  ...                                                                      |  |  |
|  |  |  [Tile (9,0)] [Tile (9,1)] [Tile (9,2)] ... [Tile (9,9)]                  |  |  |
|  |  +---------------------------------------------------------------------------+  |  |
|  |  +---------------------------------------------------------------------------+  |  |
|  |  |      EXTERNAL AXI MEMORY PHY & HIGH-SPEED DMA STREAMING PADS              |  |  |
|  |  +---------------------------------------------------------------------------+  |  |
|  +---------------------------------------------------------------------------------+  |
+---------------------------------------------------------------------------------------+
```

### 1.2 Tile Layout Specifications
- **Cluster Tile Dimension**: Standard macro pitch with abutted NoC boundary routing.
- **Aspect Ratio**: 1:1 square tile for optimal routing symmetry.
- **Metal Layer Stack Utilization (90nm GPDK 9-Metal Flow)**:
  - **M1 - M3**: Standard Cell local interconnections.
  - **M4 - M5**: Intermediate signal routing & cluster-internal scratchpad crossbar.
  - **M6 - M7**: Inter-cluster 2D-Mesh NoC flit channels (160-bit wide links).
  - **M8 - M9**: Global Clock Tree H-Tree trunk and VDD/VSS Power Straps.

---

## 2. Synchronous Clock & Reset Architecture

### 2.1 Single Synchronous Clock Domain Contract
All logic operates in a single authoritative synchronous clock domain (`clk`):

```
                 clk
                  │
         ┌────────▼────────┐
         │ sequential logic│
         └────────┬────────┘
                  │
             combinational
                 logic
                  │
         ┌────────▼────────┐
         │ next registers  │
         └─────────────────┘
```

**RTL Interface & Clocking Rules:**
1. **Synchronous Sampling**: All inputs to a synchronous module are sampled strictly on `posedge clk`.
2. **Registered Outputs**: Registered outputs transition only according to sequential flip-flop updates.
3. **No Simulation Delays in RTL**: No `#1`, `#5`, `#10` in synthesizable RTL.
4. **No Combinational Feedback**: Strictly acyclic combinational paths.
5. **No Direct Combinational Gating**: Never use `assign gated_clk = clk & enable;`. Use library Integrated Clock Gating (ICG) cells.
6. **No Internally Generated Clocks**: 0 generated clocks without approved source; 1 authoritative clock name (`clk`) with target period $T_{\text{clk}} = 1.0\text{ ns}$ (1.0 GHz).
7. **Reset Methodology**: Asynchronous assertion, synchronous deassertion (`rst_n`) distributed via a 2-stage synchronizer.

---

## 3. SDC Timing Constraints Methodology

### 3.1 Clock Definition & Uncertainty
```tcl
# Authoritative Primary Clock
create_clock -name clk -period 1.000 [get_ports clk]

# Clock Uncertainty (Setup & Hold)
set_clock_uncertainty -setup 0.050 [get_clocks clk]
set_clock_uncertainty -hold  0.020 [get_clocks clk]
set_clock_transition 0.050 [get_clocks clk]
```
> **Note**: 1.0 GHz ($T_{\text{clk}} = 1.0\text{ ns}$) is the architectural target. The achieved operating frequency is determined by Tempus STA signoff.

### 3.2 Synchronous Interface Delays
- **Primary Clock**: No input delay applied to `clk`.
- **Synchronous Inputs/Outputs**: Delays applied based strictly on interface contracts:
```tcl
# Host CSR Interface
set_input_delay  -clock [get_clocks clk] -max 0.250 [get_ports {host_csr_valid host_csr_write host_csr_addr[*] host_csr_wdata[*]}]
set_output_delay -clock [get_clocks clk] -max 0.250 [get_ports {host_csr_ready host_csr_rdata[*]}]

# Host DMA Interface (512-bit streaming)
set_input_delay  -clock [get_clocks clk] -max 0.300 [get_ports {host_dma_req_val host_dma_req_wr host_dma_req_addr[*] host_dma_req_wdata[*] host_dma_req_len[*]}]
set_output_delay -clock [get_clocks clk] -max 0.300 [get_ports {host_dma_req_rdy host_dma_resp_val host_dma_resp_rdata[*] host_dma_done}]

# External Memory Interface
set_input_delay  -clock [get_clocks clk] -max 0.300 [get_ports {ext_mem_rdy ext_mem_resp_val ext_mem_resp_rdata[*]}]
set_output_delay -clock [get_clocks clk] -max 0.300 [get_ports {ext_mem_val ext_mem_wr ext_mem_addr[*] ext_mem_wdata[*]}]
```

### 3.3 Zero-Unconstrained Policy
Before timing signoff:
- **0 unconstrained clocks**
- **0 unconstrained sequential endpoints**
- **0 unintended clock domains**
- **0 missing input delays**
- **0 missing output delays**

---

## 4. Timing Slack & Signoff Requirements

### 4.1 Hard Signoff Criteria
- **Worst Negative Slack (Setup)**: $\text{WNS} \ge 0\text{ ps}$
- **Total Negative Slack (Setup)**: $\text{TNS} = 0\text{ ps}$
- **Worst Hold Slack (Hold)**: $\text{WHS} \ge 0\text{ ps}$
- **Total Hold Slack (Hold)**: $\text{THS} = 0\text{ ps}$
- **Signoff Rule**: **NO NEGATIVE SLACK** across all required PVT corners and operating modes.

### 4.2 Engineering Margin Target
- **Target Setup Margin**: $100\text{ ps} - 200\text{ ps}$ positive slack during initial synthesis restructuring.
- Excessive artificial slack demands (e.g. requiring $>500\text{ ps}$ on a $1.0\text{ ns}$ clock) are avoided to prevent unnecessary area and dynamic power penalties.

---

## 5. Formal Cadence Signoff Tables

### 5.1 Final RTL Quality Signoff Table
| Quality Metric | Signoff Requirement | Status |
|---|---|---|
| RTL Lint Errors | **0** | `PLANNED` |
| RTL Unresolved Warnings | **0 critical** | `PLANNED` |
| Unresolved Module References | **0** | `PLANNED` |
| Multiple Drivers | **0** | `PLANNED` |
| Unintended Latches | **0** | `PLANNED` |
| Combinational Loops | **0** | `PLANNED` |
| Undriven Required Signals | **0** | `PLANNED` |
| Out-of-Scope Production Modules | **0** | `PLANNED` |
| Duplicate Functional Modules | **0** | `PLANNED` |
| Production MCTS Modules in V1 | **0** | `PLANNED` |
| Production Coherent D-Cache in V1 | **0** | `PLANNED` |

### 5.2 Final Genus Synthesis Signoff Table
| Synthesis Metric | Signoff Requirement | Status |
|---|---|---|
| RTL Compilation | **PASS** | `PLANNED` |
| Design Elaboration | **PASS** | `PLANNED` |
| `check_design` Quality Check | **CLEAN** | `PLANNED` |
| Unintended Inferred Latches | **0** | `PLANNED` |
| Multiple Drivers | **0** | `PLANNED` |
| Unresolved References / Black Boxes | **0** | `PLANNED` |
| Unconnected Required Ports | **0** | `PLANNED` |
| Area Report | **GENERATED** | `PLANNED` |
| Timing / Slack Report | **GENERATED** | `PLANNED` |
| Power Estimate (Leakage + Dynamic) | **GENERATED** | `PLANNED` |
| Gate-Level Verilog Netlist | **GENERATED** | `PLANNED` |
| SDC Constraints Applied | **PASS** | `PLANNED` |

### 5.3 Final LEC (Logic Equivalence Checking) Signoff Table
| LEC Comparison Metric | Signoff Requirement | Status |
|---|---|---|
| Unmapped Compare Points | **0 unresolved** | `PLANNED` |
| Unmatched Points | **0** | `PLANNED` |
| Non-Equivalent Points | **0** | `PLANNED` |
| Unproven Points | **0** | `PLANNED` |
| Undetectable Points | **0 unresolved** | `PLANNED` |
| Unexpected Black Boxes | **0** | `PLANNED` |
| Clock Mismatches | **0** | `PLANNED` |
| Reset Mismatches | **0** | `PLANNED` |

### 5.4 Final Tempus STA Signoff Table
| STA Metric | Signoff Requirement | Status |
|---|---|---|
| Worst Negative Slack (Setup) | $\mathbf{WNS \ge 0\text{ ps}}$ | `PLANNED` |
| Total Negative Slack (Setup) | $\mathbf{TNS = 0\text{ ps}}$ | `PLANNED` |
| Worst Hold Slack (Hold) | $\mathbf{WHS \ge 0\text{ ps}}$ | `PLANNED` |
| Total Hold Slack (Hold) | $\mathbf{THS = 0\text{ ps}}$ | `PLANNED` |
| Unconstrained Paths | **0** | `PLANNED` |
| Unconstrained Endpoints | **0** | `PLANNED` |
| Unresolved / Stale Clocks | **0** | `PLANNED` |
| Critical Timing Violations | **0** | `PLANNED` |
| Operating Frequency Signoff | **Achieved from Tempus Report** | `PLANNED` |

### 5.5 Final Physical & Tapeout Signoff Table
| Physical Verification Metric | Tool | Signoff Requirement | Status |
|---|---|---|---|
| Design Rule Checking (DRC) | Pegasus / PVS | **0 Errors** | `BLOCKED` |
| Layout vs Schematic (LVS) | Pegasus / PVS | **0 Errors (Clean Match)** | `BLOCKED` |
| Negative Setup Slack | Tempus | **0 ps (WNS $\ge 0$)** | `BLOCKED` |
| Negative Hold Slack | Tempus | **0 ps (WHS $\ge 0$)** | `BLOCKED` |
| Unconstrained Timing Paths | Tempus | **0** | `BLOCKED` |
| Critical IR-Drop Violations | Voltus | **0 (< 25 mV budget)** | `BLOCKED` |
| Electromigration (EM) Violations | Voltus | **0** | `BLOCKED` |
| Antenna Rule Violations | Pegasus | **0** | `BLOCKED` |
| GDSII Stream-Out | Innovus | **PASS** | `BLOCKED` |
