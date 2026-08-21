#=============================================================================
# Cadence Genus Synthesis Script
# Design: 100-Core Custom RISC-V AI GPU (Many-Core AI Accelerator Prototype)
# Target: ASIC Standard Cell Flow
#=============================================================================

set_db / .information_level 7

# 1. Target Library Setup (Replace with actual foundry/academic PDK .lib path)
# e.g., NangateOpenCellLibrary_typical.lib, ASAP7, or FreePDK45
set_db / .target_library [list /tools/pdk/lib/typical.lib]
set_db / .link_library   [list /tools/pdk/lib/typical.lib]

# 2. Design Search Paths & HDL Configuration
set_db / .hdl_array_naming_style %s_%d
set_db / .hdl_parameter_naming_style _%s%d

set_db / .init_hdl_search_path [list ./rtl/include ./rtl/core ./rtl/neural ./rtl/agentic ./rtl/noc ./rtl/cluster ./rtl/memory ./rtl/top]

# 3. Read SystemVerilog RTL Codebase
read_hdl -language sv -define SYNTHESIS [list \
    ./rtl/include/riscv_ai_gpu_pkg.sv \
    ./rtl/include/agentic_isa_defs.sv \
    ./rtl/core/core_warp_scheduler.sv \
    ./rtl/core/core_fetch_unit.sv \
    ./rtl/core/core_decode_unit.sv \
    ./rtl/core/core_regfile.sv \
    ./rtl/core/core_scalar_alu.sv \
    ./rtl/core/core_vector_unit.sv \
    ./rtl/core/core_lsu_dcache.sv \
    ./rtl/core/riscv_ai_core.sv \
    ./rtl/neural/systolic_pe.sv \
    ./rtl/neural/neural_systolic_engine_8x8.sv \
    ./rtl/neural/neural_activation_unit.sv \
    ./rtl/neural/neural_softmax_unit.sv \
    ./rtl/agentic/agent_dag_scheduler.sv \
    ./rtl/agentic/paged_kv_cache_mgr.sv \
    ./rtl/agentic/agent_tree_search_engine.sv \
    ./rtl/agentic/agent_token_router.sv \
    ./rtl/agentic/agentic_coprocessor_top.sv \
    ./rtl/noc/noc_router_5port.sv \
    ./rtl/noc/noc_interface_adapter.sv \
    ./rtl/cluster/cluster_scratchpad_sram.sv \
    ./rtl/cluster/cluster_barrier_sync.sv \
    ./rtl/cluster/ai_gpu_cluster.sv \
    ./rtl/memory/l2_cache_bank.sv \
    ./rtl/memory/l2_directory_ctrl.sv \
    ./rtl/memory/axi_dma_controller.sv \
    ./rtl/top/riscv_ai_gpu_top.sv \
]

# 4. Elaborate Top-Level Module
elaborate riscv_ai_gpu_top

# 5. Read Timing Constraints
read_sdc ./scripts/constraints.sdc

# 6. Check Design & SDC Consistency
check_design -unresolved
check_timing_intent

# 7. Generic Logic Synthesis
syn_generic

# 8. Technology Mapping
syn_map

# 9. Timing / Area / Power Optimization
syn_opt

# 10. Generate Quality-of-Results (QoR) Reports
file mkdir ./reports
report_timing -max_paths 50 > ./reports/timing_max_paths.rpt
report_area                 > ./reports/area_hierarchical.rpt
report_power                > ./reports/power_dynamic_leakage.rpt
report_qor                  > ./reports/qor_summary.rpt

# 11. Export Synthesized Gate-Level Netlist & SDC
file mkdir ./netlist
write_hdl -mapped > ./netlist/riscv_ai_gpu_top_netlist.v
write_sdc         > ./netlist/riscv_ai_gpu_top_out.sdc

puts "=========================================================================="
puts " Genus Synthesis Complete: Gate-Level Netlist & Reports exported to ./netlist and ./reports"
puts "=========================================================================="
