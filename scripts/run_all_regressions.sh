#!/bin/bash
#=============================================================================
# Master Regression Runner with Cadence Xcelium & Coverage Collection
# Design: 100-Core Custom RISC-V SIMT AI GPU (Production V1)
# Directory: /mnt/rl-home/THIRU/syn_workshop/riscv_ai_gpu/work
#=============================================================================

source ../scripts/setup_cadence_env.sh 2>/dev/null || true

COV_DIR="./cov_work"
mkdir -p "$COV_DIR"

TOTAL_PASS=0
TOTAL_FAIL=0

echo "================================================================================"
echo " 100-CORE RISC-V AI GPU: CADENCE REGRESSION SUITE EXECUTION"
echo "================================================================================"

run_test() {
    TEST_NAME=$1
    DUT_NAME=$2
    shift 2
    FILES="$@"

    echo ""
    echo "--------------------------------------------------------------------------------"
    echo " [*] Running Test: $TEST_NAME on DUT: $DUT_NAME"
    echo "--------------------------------------------------------------------------------"

    rm -rf xcelium.d INCA_libs *.history *.log *.key .*.lock 2>/dev/null || true

    xrun -64bit -sv -access +rwc -run -exit \
         -coverage all \
         -covdut "$DUT_NAME" \
         -covworkdir "$COV_DIR" \
         -covtest "$TEST_NAME" \
         -covoverwrite \
         -incdir ../rtl/include \
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

# 1. Core Unit Test (Compute Engine RV32IM + 256b SIMD)
run_test "tb_riscv_ai_core" "riscv_ai_core" \
    ../rtl/include/riscv_ai_gpu_pkg.sv \
    ../rtl/core/core_fetch_unit.sv \
    ../rtl/core/core_decode_unit.sv \
    ../rtl/core/core_regfile.sv \
    ../rtl/core/core_scalar_alu.sv \
    ../rtl/core/core_vector_unit.sv \
    ../rtl/core/core_warp_scheduler.sv \
    ../rtl/core/core_reconvergence_stack.sv \
    ../rtl/core/core_lsu.sv \
    ../rtl/core/riscv_ai_core.sv \
    ../tb/unit_tb/tb_riscv_ai_core.sv

# 2. Neural Systolic Array Engine Test (8x8 INT8 NMU)
run_test "tb_neural_systolic_engine" "neural_systolic_engine_8x8" \
    ../rtl/include/riscv_ai_gpu_pkg.sv \
    ../rtl/neural/systolic_pe.sv \
    ../rtl/neural/neural_systolic_engine_8x8.sv \
    ../tb/unit_tb/tb_neural_systolic_engine.sv

# 3. 5-Port Virtual-Channel NoC Router Test
run_test "tb_noc_router_5port" "noc_router_5port" \
    ../rtl/include/riscv_ai_gpu_pkg.sv \
    ../rtl/noc/noc_router_5port.sv \
    ../tb/unit_tb/tb_noc_router_5port.sv

# 4. Agentic Hardware DAG Scheduler Test
run_test "tb_agent_dag_scheduler" "agent_dag_scheduler" \
    ../rtl/include/riscv_ai_gpu_pkg.sv \
    ../rtl/agentic/agent_dag_scheduler.sv \
    ../tb/unit_tb/tb_agent_dag_scheduler.sv

# 5. Paged Attention KV-Cache Manager Test
run_test "tb_paged_kv_cache_mgr" "paged_kv_cache_mgr" \
    ../rtl/include/riscv_ai_gpu_pkg.sv \
    ../rtl/agentic/paged_kv_cache_mgr.sv \
    ../tb/unit_tb/tb_paged_kv_cache_mgr.sv

# 6. Master Full-Chip Top-Level Integration Test (100 Cores / 10 Clusters / 10x10 NoC)
run_test "tb_riscv_ai_gpu_top" "riscv_ai_gpu_top" \
    ../rtl/include/riscv_ai_gpu_pkg.sv \
    ../rtl/include/agentic_isa_defs.sv \
    ../rtl/core/*.sv \
    ../rtl/neural/*.sv \
    ../rtl/cluster/*.sv \
    ../rtl/noc/*.sv \
    ../rtl/memory/*.sv \
    ../rtl/agentic/*.sv \
    ../rtl/top/*.sv \
    ../tb/integration_tb/tb_riscv_ai_gpu_top.sv

echo ""
echo "================================================================================"
echo " REGRESSION SUMMARY: $TOTAL_PASS PASSED, $TOTAL_FAIL FAILED"
echo "================================================================================"

if [ $TOTAL_FAIL -eq 0 ]; then
    echo " RESULT: 100% REGRESSION TESTS PASSED (0 ERRORS, 0 WARNINGS)!"
    exit 0
else
    echo " RESULT: REGRESSION SUITE FAILED WITH $TOTAL_FAIL FAILURES."
    exit 1
fi
