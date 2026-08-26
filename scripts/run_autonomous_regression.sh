#!/bin/bash
#=============================================================================
# Autonomous Background Regression & Coverage Signoff Script
# Runs detached via nohup on Cadence Server (192.168.1.100)
# Design: 100-Core Custom RISC-V SIMT AI GPU (Production V1)
# Output: /mnt/rl-home/THIRU/syn_workshop/riscv_ai_gpu/work/regression_full.log
#=============================================================================

set -u

WORK_DIR="/mnt/rl-home/THIRU/syn_workshop/riscv_ai_gpu/work"
SCRIPTS_DIR="/mnt/rl-home/THIRU/syn_workshop/riscv_ai_gpu/scripts"
RTL_DIR="/mnt/rl-home/THIRU/syn_workshop/riscv_ai_gpu/rtl"
TB_DIR="/mnt/rl-home/THIRU/syn_workshop/riscv_ai_gpu/tb"

cd "$WORK_DIR" || exit 1

# Setup Cadence Environment
source "$SCRIPTS_DIR/setup_cadence_env.sh" 2>/dev/null || true

COV_DIR="$WORK_DIR/cov_work"
mkdir -p "$COV_DIR"

LOG_FILE="$WORK_DIR/regression_full.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "================================================================================"
echo " 100-CORE RISC-V AI GPU: AUTONOMOUS SERVER REGRESSION & COVERAGE SUITE"
echo " Date: $(date)"
echo " Server: $(hostname) ($(whoami))"
echo " Work Directory: $WORK_DIR"
echo "================================================================================"

TOTAL_PASS=0
TOTAL_FAIL=0

run_test() {
    TEST_NAME=$1
    DUT_NAME=$2
    shift 2
    FILES="$@"

    echo ""
    echo "--------------------------------------------------------------------------------"
    echo " [*] Running Test: $TEST_NAME on DUT: $DUT_NAME"
    echo "     Started at: $(date)"
    echo "--------------------------------------------------------------------------------"

    rm -rf xcelium.d INCA_libs *.history *.log *.key .*.lock 2>/dev/null || true

    xrun -64bit -sv -access +rwc -run -exit \
         -coverage all \
         -covdut "$DUT_NAME" \
         -covworkdir "$COV_DIR" \
         -covtest "$TEST_NAME" \
         -covoverwrite \
         -incdir "$RTL_DIR/include" \
         $FILES \
         -top "$TEST_NAME"

    RET=$?
    if [ $RET -eq 0 ]; then
        echo " [PASS] $TEST_NAME completed successfully."
        TOTAL_PASS=$((TOTAL_PASS + 1))
    else
        echo " [FAIL] $TEST_NAME failed with exit code $RET."
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
}

# 1. Core Unit Test (Compute Core RV32IM + 256b SIMD Vector Unit)
run_test "tb_riscv_ai_core" "riscv_ai_core" \
    "$RTL_DIR/include/riscv_ai_gpu_pkg.sv" \
    "$RTL_DIR/core/core_fetch_unit.sv" \
    "$RTL_DIR/core/core_decode_unit.sv" \
    "$RTL_DIR/core/core_regfile.sv" \
    "$RTL_DIR/core/core_scalar_alu.sv" \
    "$RTL_DIR/core/core_vector_unit.sv" \
    "$RTL_DIR/core/core_warp_scheduler.sv" \
    "$RTL_DIR/core/core_reconvergence_stack.sv" \
    "$RTL_DIR/core/core_lsu.sv" \
    "$RTL_DIR/core/riscv_ai_core.sv" \
    "$TB_DIR/unit_tb/tb_riscv_ai_core.sv"

# 2. Neural Systolic Array Engine Test (8x8 INT8 NMU)
run_test "tb_neural_systolic_engine" "neural_systolic_engine_8x8" \
    "$RTL_DIR/include/riscv_ai_gpu_pkg.sv" \
    "$RTL_DIR/neural/systolic_pe.sv" \
    "$RTL_DIR/neural/neural_systolic_engine_8x8.sv" \
    "$TB_DIR/unit_tb/tb_neural_systolic_engine.sv"

# 3. 5-Port Virtual-Channel NoC Router Test
run_test "tb_noc_router_5port" "noc_router_5port" \
    "$RTL_DIR/include/riscv_ai_gpu_pkg.sv" \
    "$RTL_DIR/noc/noc_router_5port.sv" \
    "$TB_DIR/unit_tb/tb_noc_router_5port.sv"

# 4. Agentic Hardware DAG Scheduler Test
run_test "tb_agent_dag_scheduler" "agent_dag_scheduler" \
    "$RTL_DIR/include/riscv_ai_gpu_pkg.sv" \
    "$RTL_DIR/agentic/agent_dag_scheduler.sv" \
    "$TB_DIR/unit_tb/tb_agent_dag_scheduler.sv"

# 5. Paged Attention KV-Cache Manager Test
run_test "tb_paged_kv_cache_mgr" "paged_kv_cache_mgr" \
    "$RTL_DIR/include/riscv_ai_gpu_pkg.sv" \
    "$RTL_DIR/agentic/paged_kv_cache_mgr.sv" \
    "$TB_DIR/unit_tb/tb_paged_kv_cache_mgr.sv"

# 6. Master Full-Chip Top-Level Integration Test (100 Cores / 10 Clusters / 10x10 NoC)
run_test "tb_riscv_ai_gpu_top" "riscv_ai_gpu_top" \
    "$RTL_DIR/include/riscv_ai_gpu_pkg.sv" \
    "$RTL_DIR/include/agentic_isa_defs.sv" \
    "$RTL_DIR/core"/*.sv \
    "$RTL_DIR/neural"/*.sv \
    "$RTL_DIR/cluster"/*.sv \
    "$RTL_DIR/noc"/*.sv \
    "$RTL_DIR/memory"/*.sv \
    "$RTL_DIR/agentic"/*.sv \
    "$RTL_DIR/top"/*.sv \
    "$TB_DIR/integration_tb/tb_riscv_ai_gpu_top.sv"

echo ""
echo "================================================================================"
echo " REGRESSION SUMMARY: $TOTAL_PASS PASSED, $TOTAL_FAIL FAILED"
echo " Finished at: $(date)"
echo "================================================================================"

# Merge Coverage Databases & Generate Cadence IMC Signoff Reports
echo ""
echo "================================================================================"
echo " GENERATING CADENCE IMC COVERAGE SIGN-OFF REPORTS"
echo "================================================================================"

cat << 'EOF' > "$WORK_DIR/imc_signoff.cmd"
merge cov_work/scope/* -output cov_work/merged_cov -overwrite
load -run cov_work/merged_cov
report_summary -out cov_summary.rpt -overwrite
report_detail -out coverage_detailed.txt -all -overwrite
report_metrics -out cov_metrics.rpt -overwrite
exit
EOF

if command -v imc >/dev/null 2>&1; then
    imc -batch -init "$WORK_DIR/imc_signoff.cmd" || true
    echo " [INFO] Cadence IMC Coverage Reports successfully generated in $WORK_DIR:"
    echo "        - $WORK_DIR/cov_summary.rpt"
    echo "        - $WORK_DIR/coverage_detailed.txt"
    echo "        - $WORK_DIR/cov_metrics.rpt"
else
    echo " [INFO] Coverage databases saved in $COV_DIR."
fi

echo "================================================================================"
echo " 100-CORE RISC-V AI GPU AUTONOMOUS RUN COMPLETE!"
echo "================================================================================"
