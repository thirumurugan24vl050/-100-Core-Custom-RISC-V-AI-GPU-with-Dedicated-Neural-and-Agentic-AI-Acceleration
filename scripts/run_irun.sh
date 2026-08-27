#!/bin/bash
#=============================================================================
# Cadence Incisive (irun) Master Regression Suite
# Design: 100-Core Custom RISC-V SIMT AI GPU (Production V1)
# Location: /mnt/rl-home/THIRU/syn_workshop/riscv_ai_gpu
#=============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup_cadence_env.sh" 2>/dev/null || true

echo "================================================================================"
echo " [CADENCE IRUN] 100-Core RISC-V AI GPU Master Regression (13 Environments)"
echo "================================================================================"

RTL_COMMON=" \
  ./rtl/include/riscv_ai_gpu_pkg.sv \
  ./rtl/include/agentic_isa_defs.sv \
  ./rtl/core/core_fetch_unit.sv \
  ./rtl/core/core_decode_unit.sv \
  ./rtl/core/core_regfile.sv \
  ./rtl/core/core_scalar_alu.sv \
  ./rtl/core/core_vector_unit.sv \
  ./rtl/core/core_warp_scheduler.sv \
  ./rtl/core/core_reconvergence_stack.sv \
  ./rtl/core/core_lsu.sv \
  ./rtl/core/riscv_ai_core.sv \
  ./rtl/neural/systolic_pe.sv \
  ./rtl/neural/neural_systolic_engine_8x8.sv \
  ./rtl/neural/neural_postproc_unit.sv \
  ./rtl/neural/neural_softmax_unit.sv \
  ./rtl/cluster/cluster_scratchpad_sram.sv \
  ./rtl/cluster/cluster_barrier_sync.sv \
  ./rtl/cluster/ai_gpu_cluster.sv \
  ./rtl/noc/noc_router_5port.sv \
  ./rtl/noc/noc_interface_adapter.sv \
  ./rtl/noc/noc_mesh_2d_10x10.sv \
  ./rtl/memory/global_buffer.sv \
  ./rtl/memory/memory_gateway.sv \
  ./rtl/memory/axi_dma_controller.sv \
  ./rtl/agentic/agent_dag_scheduler.sv \
  ./rtl/agentic/paged_kv_cache_mgr.sv \
  ./rtl/agentic/agent_token_router.sv \
  ./rtl/agentic/agentic_coprocessor_top.sv \
  ./rtl/top/riscv_ai_gpu_top.sv"

TESTS=(
  "tb_riscv_ai_core:./tb/unit_tb/tb_riscv_ai_core.sv:riscv_ai_core"
  "tb_neural_systolic_engine:./tb/unit_tb/tb_neural_systolic_engine.sv:neural_systolic_engine_8x8"
  "tb_neural_postproc:./tb/unit_tb/tb_neural_postproc.sv:neural_postproc_unit"
  "tb_neural_softmax:./tb/unit_tb/tb_neural_softmax.sv:neural_softmax_unit"
  "tb_cluster_scratchpad:./tb/unit_tb/tb_cluster_scratchpad.sv:cluster_scratchpad_sram"
  "tb_cluster_barrier:./tb/unit_tb/tb_cluster_barrier.sv:cluster_barrier_sync"
  "tb_noc_router_5port:./tb/unit_tb/tb_noc_router_5port.sv:noc_router_5port"
  "tb_noc_mesh_10x10:./tb/unit_tb/tb_noc_mesh_10x10.sv:noc_mesh_2d_10x10"
  "tb_axi_dma_controller:./tb/unit_tb/tb_axi_dma_controller.sv:axi_dma_controller"
  "tb_agent_dag_scheduler:./tb/unit_tb/tb_agent_dag_scheduler.sv:agent_dag_scheduler"
  "tb_paged_kv_cache_mgr:./tb/unit_tb/tb_paged_kv_cache_mgr.sv:paged_kv_cache_mgr"
  "tb_agentic_coprocessor:./tb/unit_tb/tb_agentic_coprocessor.sv:agentic_coprocessor_top"
  "tb_riscv_ai_gpu_top:./tb/integration_tb/tb_riscv_ai_gpu_top.sv:riscv_ai_gpu_top"
)

PASSED=0
FAILED=0

mkdir -p ./cov_work

for item in "${TESTS[@]}"; do
  IFS=":" read -r TB_NAME TB_FILE DUT_NAME <<< "$item"
  
  echo ""
  echo "--------------------------------------------------------------------------------"
  echo " [CADENCE IRUN] Executing: $TB_NAME (DUT: $DUT_NAME)"
  echo "--------------------------------------------------------------------------------"
  
  irun -clean -sv -64bit -access +rwc -run -exit \
       -coverage all -covdut "$DUT_NAME" -covworkdir ./cov_work -covtest "$TB_NAME" -covoverwrite \
       -covfile ./scripts/cov_config.ccf \
       -incdir ./rtl/include \
       $RTL_COMMON "$TB_FILE" -top "$TB_NAME"
  
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
echo " Total Environments: ${#TESTS[@]}"
echo " Total PASSED:       $PASSED"
echo " Total FAILED:       $FAILED"
echo "================================================================================"

# Merge Coverage in IMC
if command -v imc >/dev/null 2>&1; then
  echo ""
  echo "================================================================================"
  echo " [CADENCE IMC] Merging Coverage from all 13 Testbenches..."
  echo "================================================================================"
  rm -rf coverage_merged_report
  cat << 'EOF' > merge_cov.cmd
merge cov_work/scope/* -out merged_cov -overwrite
load -run merged_cov
report_metrics -detail -both -overwrite -out coverage_merged_report
EOF
  imc -64bit -exec merge_cov.cmd || true
fi

if [ $FAILED -eq 0 ]; then
  echo " >>> 100% REGRESSION CLOSURE ACHIEVED UNDER CADENCE INCISIVE (irun) <<<"
  exit 0
else
  echo " >>> REGRESSION FAILURES DETECTED <<<"
  exit 1
fi
