#=============================================================================
# Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
# File: run_sim.ps1
# Description: Automated Vivado Simulator Batch Runner for single testbenches.
#=============================================================================

param (
    [string]$TopTB = "tb_riscv_ai_core"
)

$VIVADO_BIN = "C:\Xilinx24VL044\Vivado\2018.3\bin"
$XVLOG = "$VIVADO_BIN\xvlog.bat"
$XELAB = "$VIVADO_BIN\xelab.bat"
$XSIM  = "$VIVADO_BIN\xsim.bat"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " [SIMULATION RUNNER] Compiling & Simulating: $TopTB" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Compile SystemVerilog Packages and Headers
Write-Host " [1/3] Compiling SystemVerilog Packages & Include Files..." -ForegroundColor Yellow
& $XVLOG -sv -i "./rtl/include" `
    "./rtl/include/riscv_ai_gpu_pkg.sv" `
    "./rtl/include/agentic_isa_defs.sv"

if ($LASTEXITCODE -ne 0) {
    Write-Host " [ERROR] Package compilation failed!" -ForegroundColor Red
    exit 1
}

# 2. Compile Core, Neural, Agentic, NoC, Memory, Cluster, and Top RTL Files
Write-Host " [2/3] Compiling RTL and Testbench Modules..." -ForegroundColor Yellow
& $XVLOG -sv -i "./rtl/include" `
    "./rtl/core/*.sv" `
    "./rtl/neural/*.sv" `
    "./rtl/agentic/*.sv" `
    "./rtl/noc/*.sv" `
    "./rtl/cluster/*.sv" `
    "./rtl/memory/*.sv" `
    "./rtl/top/*.sv" `
    "./tb/unit_tb/*.sv" `
    "./tb/cluster_tb/*.sv" `
    "./tb/top_tb/*.sv"

if ($LASTEXITCODE -ne 0) {
    Write-Host " [ERROR] RTL compilation failed!" -ForegroundColor Red
    exit 1
}

# 3. Elaborate Top-Level Testbench
Write-Host " [3/3] Elaborating & Running Simulation: $TopTB..." -ForegroundColor Yellow
& $XELAB -timescale 1ns/1ps -debug typical -top $TopTB -snapshot "${TopTB}_snap"

if ($LASTEXITCODE -ne 0) {
    Write-Host " [ERROR] Elaboration failed!" -ForegroundColor Red
    exit 1
}

# 4. Execute Simulation in Batch Mode
& $XSIM "${TopTB}_snap" -R

Write-Host "================================================================================" -ForegroundColor Green
Write-Host " [SIMULATION RUNNER] Completed: $TopTB" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
