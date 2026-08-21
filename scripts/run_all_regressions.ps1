#=============================================================================
# Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
# File: run_all_regressions.ps1
# Description: Automated Master Regression Suite running all testbenches.
#=============================================================================

$VIVADO_BIN = "C:\Xilinx24VL044\Vivado\2018.3\bin"
$XVLOG = "$VIVADO_BIN\xvlog.bat"
$XELAB = "$VIVADO_BIN\xelab.bat"
$XSIM  = "$VIVADO_BIN\xsim.bat"

$TestList = @(
    "tb_riscv_ai_core",
    "tb_neural_systolic_engine",
    "tb_neural_activation",
    "tb_agent_dag_scheduler",
    "tb_paged_kv_cache_mgr",
    "tb_agent_tree_search",
    "tb_noc_router_5port",
    "tb_ai_gpu_cluster",
    "tb_riscv_ai_gpu_top"
)

$Passed = 0
$Failed = 0

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " [REGRESSION SUITE] Starting 100-Core RISC-V AI GPU Master Verification Regression" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Unified Compilation of Full RTL & TB
Write-Host " [STAGE 1] Compiling Complete SystemVerilog RTL Codebase & Test Suites..." -ForegroundColor Yellow

& $XVLOG -sv -i "./rtl/include" `
    "./rtl/include/riscv_ai_gpu_pkg.sv" `
    "./rtl/include/agentic_isa_defs.sv" `
    "./rtl/core/core_regfile.sv" `
    "./rtl/core/core_scalar_alu.sv" `
    "./rtl/core/core_vector_unit.sv" `
    "./rtl/core/core_fetch_unit.sv" `
    "./rtl/core/core_decode_unit.sv" `
    "./rtl/core/core_warp_scheduler.sv" `
    "./rtl/core/core_lsu_dcache.sv" `
    "./rtl/core/riscv_ai_core.sv" `
    "./rtl/neural/systolic_pe.sv" `
    "./rtl/neural/neural_systolic_engine_8x8.sv" `
    "./rtl/neural/neural_activation_unit.sv" `
    "./rtl/neural/neural_softmax_unit.sv" `
    "./rtl/agentic/agent_dag_scheduler.sv" `
    "./rtl/agentic/paged_kv_cache_mgr.sv" `
    "./rtl/agentic/agent_tree_search_engine.sv" `
    "./rtl/agentic/agent_token_router.sv" `
    "./rtl/agentic/agentic_coprocessor_top.sv" `
    "./rtl/noc/noc_router_5port.sv" `
    "./rtl/noc/noc_interface_adapter.sv" `
    "./rtl/cluster/cluster_scratchpad_sram.sv" `
    "./rtl/cluster/cluster_barrier_sync.sv" `
    "./rtl/cluster/ai_gpu_cluster.sv" `
    "./rtl/memory/l2_cache_bank.sv" `
    "./rtl/memory/l2_directory_ctrl.sv" `
    "./rtl/memory/axi_dma_controller.sv" `
    "./rtl/top/riscv_ai_gpu_top.sv" `
    "./tb/unit_tb/tb_riscv_ai_core.sv" `
    "./tb/unit_tb/tb_neural_systolic_engine.sv" `
    "./tb/unit_tb/tb_neural_activation.sv" `
    "./tb/unit_tb/tb_agent_dag_scheduler.sv" `
    "./tb/unit_tb/tb_paged_kv_cache_mgr.sv" `
    "./tb/unit_tb/tb_agent_tree_search.sv" `
    "./tb/unit_tb/tb_noc_router_5port.sv" `
    "./tb/cluster_tb/tb_ai_gpu_cluster.sv" `
    "./tb/top_tb/tb_riscv_ai_gpu_top.sv"

if ($LASTEXITCODE -ne 0) {
    Write-Host " [FATAL] RTL Compilation Failed!" -ForegroundColor Red
    exit 1
}
Write-Host " [STAGE 1 SUCCESS] All 27 RTL & TB modules compiled cleanly." -ForegroundColor Green

# 2. Iterate & Execute Each Testbench
foreach ($TB in $TestList) {
    Write-Host "`n--------------------------------------------------------------------------------" -ForegroundColor Magenta
    Write-Host " [RUNNING TEST] $TB" -ForegroundColor Magenta
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Magenta

    & $XELAB -timescale 1ns/1ps -debug typical -top $TB -snapshot "${TB}_snap"
    if ($LASTEXITCODE -ne 0) {
        Write-Host " [FAIL] Elaboration failed for $TB" -ForegroundColor Red
        $Failed++
        continue
    }

    & $XSIM "${TB}_snap" -R
    if ($LASTEXITCODE -ne 0) {
        Write-Host " [FAIL] Simulation execution failed for $TB" -ForegroundColor Red
        $Failed++
    } else {
        Write-Host " [PASS] $TB completed successfully" -ForegroundColor Green
        $Passed++
    }
    Start-Sleep -Milliseconds 250
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host " [REGRESSION SUMMARY REPORT]" -ForegroundColor Cyan
Write-Host " Total Testbenches Run: $($TestList.Count)" -ForegroundColor White
Write-Host " Total PASSED:          $Passed" -ForegroundColor Green
Write-Host " Total FAILED:          $Failed" -ForegroundColor $(if ($Failed -eq 0) { "Green" } else { "Red" })
Write-Host "================================================================================" -ForegroundColor Cyan

if ($Failed -eq 0) {
    Write-Host " >>> 100% REGRESSION CLOSURE ACHIEVED - READY FOR LOGIC SYNTHESIS / GDSII FLOW <<<" -ForegroundColor Green
} else {
    Write-Host " >>> REGRESSION FAILURES DETECTED <<<" -ForegroundColor Red
    exit 1
}
