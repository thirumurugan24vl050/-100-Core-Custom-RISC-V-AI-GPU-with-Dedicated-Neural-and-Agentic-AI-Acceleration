#!/bin/bash
#=============================================================================
# Helper Script to run from inside the work/ directory
#=============================================================================

# Ensure we are inside work directory
mkdir -p work
cd work

echo "Executing tb_riscv_ai_core from inside work directory..."
irun -sv -64bit -access +rwc -coverage all -covdut riscv_ai_core \
     -covworkdir ./cov_work -covtest tb_riscv_ai_core -covoverwrite \
     -incdir ../rtl/include -f ../scripts/rtl_files.f \
     ../tb/unit_tb/tb_riscv_ai_core.sv -top tb_riscv_ai_core -run -exit
