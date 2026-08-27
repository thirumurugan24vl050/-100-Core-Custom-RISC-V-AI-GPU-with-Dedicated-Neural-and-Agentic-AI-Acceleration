#!/bin/bash
#=============================================================================
# Script to launch Interactive GUI Simulation (SimVision + Coverage)
# Usage: bash scripts/run_gui_sim.sh [testbench_name]
# Example: bash scripts/run_gui_sim.sh tb_riscv_ai_core
#=============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup_cadence_env.sh" 2>/dev/null || true

cd "$SCRIPT_DIR/../work" 2>/dev/null || cd "$SCRIPT_DIR/.."

TB="${1:-tb_riscv_ai_core}"
DUT="${2:-riscv_ai_core}"

echo "================================================================================"
echo " [CADENCE GUI SIM] Launching SimVision & Coverage for: $TB"
echo "================================================================================"

irun -sv -64bit -access +rwc -gui -coverage all \
     -covdut "$DUT" -covworkdir ./cov_work -covtest "$TB" -covoverwrite \
     -covfile ./scripts/cov_config.ccf \
     -incdir ./rtl/include -f ./scripts/rtl_files.f \
     "./tb/unit_tb/${TB}.sv" -top "$TB"
