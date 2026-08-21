# Physical Design & Implementation Plan: 100-Core Custom RISC-V AI GPU

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
|  |  |      16-BANK DISTRIBUTED L2 CACHE MEMORY MACROS (4MB SRAM Macro Array)    |  |  |
|  |  +---------------------------------------------------------------------------+  |  |
|  +---------------------------------------------------------------------------------+  |
+---------------------------------------------------------------------------------------+
```

### 1.2 Tile Layout Specifications
- **Cluster Tile Dimension**: Standard macro pitch with abutted NoC boundary routing.
- **Aspect Ratio**: 1:1 square tile for optimal routing symmetry.
- **Metal Layer Stack Utilization**:
  - **M1 - M3**: Standard Cell local interconnections.
  - **M4 - M5**: Intermediate signal routing & cluster-internal scratchpad crossbar.
  - **M6 - M7**: Inter-cluster 2D-Mesh NoC flit channels (128-bit wide links).
  - **M8 - M9**: Global Clock Tree H-Tree trunk and VDD/VSS Power Straps.

---

## 2. Power Grid Planning & Distribution (PDN)
- **Target Operating Voltage (VDD)**: 0.8V nominal (0.72V worst-case corner).
- **Core Power Grid**: Interleaved VDD/VSS mesh on top-level metals (M8/M9) with IR-drop budget < 25 mV (3% of nominal VDD).
- **Power Gating Strategy**: Header power switches per compute cluster to support dynamic cluster power-down when idle.

---

## 3. Clock Tree Synthesis (CTS) Strategy
- **Architecture**: Balanced Multi-Level Symmetric H-Tree network distributing the 1.0 GHz primary clock `clk`.
- **Target Skew Budget**: $< 35\text{ ps}$ inter-cluster clock skew across all 100 cores.
- **Target Clock Slew**: $< 40\text{ ps}$ transition time at all clock leaf pins.
- **Clock Gating**: Integrated Clock Gating (ICG) cells inserted at the register bank level of each warp and systolic PE array.

---

## 4. Signal Integrity & Timing Closure Flow
1. **Design Rule Constraints (DRC)**: Strict max transition, max capacitance, and max fanout budgets.
2. **Setup / Hold Signoff**:
   - Max delay setup checks at Fast-Process / Low-Voltage / High-Temperature (WCS corner).
   - Min delay hold checks with hold buffer tree insertion at Best-Case Fast (BCF corner).
3. **Electromigration & IR-Drop Analysis**: Static and Dynamic IR-drop signoff prior to GDSII stream-out.
