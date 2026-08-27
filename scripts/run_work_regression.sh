#!/bin/bash
#=============================================================================
# Cadence Incisive (irun) Regression Suite for work/ directory
# Design: 100-Core Custom RISC-V SIMT AI GPU
#=============================================================================

# Ensure symlinks exist in current work directory
ln -sf ../rtl ./rtl 2>/dev/null || true
ln -sf ../tb ./tb 2>/dev/null || true
ln -sf ../scripts ./scripts 2>/dev/null || true

source ./scripts/setup_cadence_env.sh 2>/dev/null || true

echo "================================================================================"
echo " [CADENCE IRUN] Running 13 Environments inside $(pwd)"
echo "================================================================================"

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
  echo " [CADENCE IRUN] Running: $TB_NAME"
  echo "--------------------------------------------------------------------------------"
  
  irun -clean -sv -64bit -access +rwc -run -exit \
       -coverage all -covdut "$DUT_NAME" -covworkdir ./cov_work -covtest "$TB_NAME" -covoverwrite \
       -covfile ./scripts/cov_config.ccf \
       -incdir ./rtl/include -f ./scripts/rtl_files.f \
       "$TB_FILE" -top "$TB_NAME"
  
  if [ $? -eq 0 ]; then
    echo " [PASS] $TB_NAME"
    ((PASSED++))
  else
    echo " [FAIL] $TB_NAME"
    ((FAILED++))
  fi
done

echo ""
echo "================================================================================"
echo " [REGRESSION SUMMARY in work/]"
echo " Total Environments: ${#TESTS[@]}"
echo " Total PASSED:       $PASSED"
echo " Total FAILED:       $FAILED"
echo "================================================================================"

if command -v imc >/dev/null 2>&1; then
  echo ""
  echo " [CADENCE IMC] Merging coverage databases..."
  rm -rf coverage_merged_report merged_cov
  cat << 'EOF' > merge_cov.cmd
merge cov_work/scope/* -out merged_cov -overwrite
load -run merged_cov
report_metrics -detail -both -overwrite -out coverage_merged_report
EOF
  imc -64bit -exec merge_cov.cmd || true
fi
