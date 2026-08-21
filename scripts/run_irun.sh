#!/bin/bash
#=============================================================================
# Cadence Incisive (irun) Master Regression Suite
# Design: 100-Core Custom RISC-V AI GPU Prototype
# Location: /mnt/rl-home/THIRU/syn_workshop/riscv_ai_gpu
#=============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup_cadence_env.sh"

echo "================================================================================"
echo " [CADENCE IRUN] 100-Core RISC-V AI GPU Master Regression Suite"
echo "================================================================================"

RTL_COMMON=" \
  ./rtl/include/riscv_ai_gpu_pkg.sv \
  ./rtl/include/agentic_isa_defs.sv \
  ./rtl/core/core_regfile.sv \
  ./rtl/core/core_scalar_alu.sv \
  ./rtl/core/core_vector_unit.sv \
  ./rtl/core/core_fetch_unit.sv \
  ./rtl/core/core_decode_unit.sv \
  ./rtl/core/core_warp_scheduler.sv \
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
  ./rtl/top/riscv_ai_gpu_top.sv"

TESTS=(
  "tb_riscv_ai_core:./tb/unit_tb/tb_riscv_ai_core.sv"
  "tb_neural_systolic_engine:./tb/unit_tb/tb_neural_systolic_engine.sv"
  "tb_neural_activation:./tb/unit_tb/tb_neural_activation.sv"
  "tb_agent_dag_scheduler:./tb/unit_tb/tb_agent_dag_scheduler.sv"
  "tb_paged_kv_cache_mgr:./tb/unit_tb/tb_paged_kv_cache_mgr.sv"
  "tb_agent_tree_search:./tb/unit_tb/tb_agent_tree_search.sv"
  "tb_noc_router_5port:./tb/unit_tb/tb_noc_router_5port.sv"
  "tb_ai_gpu_cluster:./tb/cluster_tb/tb_ai_gpu_cluster.sv"
  "tb_riscv_ai_gpu_top:./tb/top_tb/tb_riscv_ai_gpu_top.sv"
)

PASSED=0
FAILED=0

for item in "${TESTS[@]}"; do
  TB_NAME="${item%%:*}"
  TB_FILE="${item##*:}"
  
  echo ""
  echo "--------------------------------------------------------------------------------"
  echo " [CADENCE IRUN] Executing: $TB_NAME"
  echo "--------------------------------------------------------------------------------"
  
  irun -clean -sv -access +rwc -input "$SCRIPT_DIR/sim.tcl" -incdir ./rtl/include $RTL_COMMON $TB_FILE -top $TB_NAME
  
  if [ $? -eq 0 ]; then
    echo " [PASS] $TB_NAME completed successfully under Cadence irun"
    ((PASSED++))
  else
    echo " [FAIL] $TB_NAME failed under Cadence irun"
    ((FAILED++))
  fi
done

echo ""
echo "================================================================================"
echo " [CADENCE IRUN REGRESSION REPORT]"
echo " Total Tests:  ${#TESTS[@]}"
echo " Total PASSED: $PASSED"
echo " Total FAILED: $FAILED"
echo "================================================================================"

if [ $FAILED -eq 0 ]; then
  echo " >>> 100% REGRESSION CLOSURE ACHIEVED UNDER CADENCE INCISIVE (irun) <<<"
  exit 0
else
  echo " >>> REGRESSION FAILURES DETECTED <<<"
  exit 1
fi
