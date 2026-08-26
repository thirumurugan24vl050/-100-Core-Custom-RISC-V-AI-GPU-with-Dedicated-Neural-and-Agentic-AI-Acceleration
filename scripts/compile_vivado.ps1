#=============================================================================
# Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
# File: compile_vivado.ps1
# Description: Clean Native Vivado xvlog/xelab/xsim runner
#=============================================================================

$vivadoLib = "C:\Xilinx24VL044\Vivado\2018.3\lib\win64.o"
$vivadoBin = "C:\Xilinx24VL044\Vivado\2018.3\bin\unwrapped\win64.o"
$env:Path = "$vivadoBin;$vivadoLib;" + $env:Path

$xvlogExe = "$vivadoBin\xvlog.exe"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " [VIVADO COMPILATION] Compiling All 28 Production V1 RTL Modules" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

$rtlFiles = @(
    "./rtl/include/riscv_ai_gpu_pkg.sv",
    "./rtl/core/core_fetch_unit.sv",
    "./rtl/core/core_decode_unit.sv",
    "./rtl/core/core_regfile.sv",
    "./rtl/core/core_scalar_alu.sv",
    "./rtl/core/core_vector_unit.sv",
    "./rtl/core/core_warp_scheduler.sv",
    "./rtl/core/core_reconvergence_stack.sv",
    "./rtl/core/core_lsu.sv",
    "./rtl/core/riscv_ai_core.sv",
    "./rtl/neural/systolic_pe.sv",
    "./rtl/neural/neural_systolic_engine_8x8.sv",
    "./rtl/neural/neural_postproc_unit.sv",
    "./rtl/neural/neural_softmax_unit.sv",
    "./rtl/cluster/cluster_scratchpad_sram.sv",
    "./rtl/cluster/cluster_barrier_sync.sv",
    "./rtl/cluster/ai_gpu_cluster.sv",
    "./rtl/noc/noc_router_5port.sv",
    "./rtl/noc/noc_interface_adapter.sv",
    "./rtl/noc/noc_mesh_2d_10x10.sv",
    "./rtl/memory/global_buffer.sv",
    "./rtl/memory/memory_gateway.sv",
    "./rtl/memory/axi_dma_controller.sv",
    "./rtl/agentic/agent_dag_scheduler.sv",
    "./rtl/agentic/paged_kv_cache_mgr.sv",
    "./rtl/agentic/agent_token_router.sv",
    "./rtl/agentic/agentic_coprocessor_top.sv",
    "./rtl/top/riscv_ai_gpu_top.sv"
)

$args = @("-sv", "-i", "./rtl/include") + $rtlFiles
& $xvlogExe $args

if ($LASTEXITCODE -eq 0) {
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Green
    Write-Host " [SUCCESS] 100% of Production V1 RTL Codebase Compiled Cleanly (0 Errors)!" -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor Green
} else {
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Red
    Write-Host " [FAILURE] Compilation failed with exit code $LASTEXITCODE" -ForegroundColor Red
    Write-Host "================================================================================" -ForegroundColor Red
}
