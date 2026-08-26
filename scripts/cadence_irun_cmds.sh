#!/bin/bash
#=============================================================================
# Cadence Incisive (irun) Master Command Reference & Suite
# Design: 100-Core Custom RISC-V SIMT AI GPU (Production V1)
# Location: /mnt/rl-home/THIRU/syn_workshop/riscv_ai_gpu/work
#=============================================================================

source ../scripts/setup_cadence_env.sh 2>/dev/null || true

echo "================================================================================"
echo " CADENCE IRUN COMMAND REFERENCE SUITE (13 PRODUCTION V1 ENVIRONMENTS)"
echo "================================================================================"

# 1. tb_riscv_ai_core
# irun -sv -64bit -access +rwc -coverage all -covdut riscv_ai_core -covworkdir ./cov_work -covtest tb_riscv_ai_core -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/core/*.sv ../tb/unit_tb/tb_riscv_ai_core.sv -top tb_riscv_ai_core

# 2. tb_neural_systolic_engine
# irun -sv -64bit -access +rwc -coverage all -covdut neural_systolic_engine_8x8 -covworkdir ./cov_work -covtest tb_neural_systolic_engine -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/neural/systolic_pe.sv ../rtl/neural/neural_systolic_engine_8x8.sv ../tb/unit_tb/tb_neural_systolic_engine.sv -top tb_neural_systolic_engine

# 3. tb_neural_postproc
# irun -sv -64bit -access +rwc -coverage all -covdut neural_postproc_unit -covworkdir ./cov_work -covtest tb_neural_postproc -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/neural/neural_postproc_unit.sv ../tb/unit_tb/tb_neural_postproc.sv -top tb_neural_postproc

# 4. tb_neural_softmax
# irun -sv -64bit -access +rwc -coverage all -covdut neural_softmax_unit -covworkdir ./cov_work -covtest tb_neural_softmax -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/neural/neural_softmax_unit.sv ../tb/unit_tb/tb_neural_softmax.sv -top tb_neural_softmax

# 5. tb_cluster_scratchpad
# irun -sv -64bit -access +rwc -coverage all -covdut cluster_scratchpad_sram -covworkdir ./cov_work -covtest tb_cluster_scratchpad -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/cluster/cluster_scratchpad_sram.sv ../tb/unit_tb/tb_cluster_scratchpad.sv -top tb_cluster_scratchpad

# 6. tb_cluster_barrier
# irun -sv -64bit -access +rwc -coverage all -covdut cluster_barrier_sync -covworkdir ./cov_work -covtest tb_cluster_barrier -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/cluster/cluster_barrier_sync.sv ../tb/unit_tb/tb_cluster_barrier.sv -top tb_cluster_barrier

# 7. tb_noc_router_5port
# irun -sv -64bit -access +rwc -coverage all -covdut noc_router_5port -covworkdir ./cov_work -covtest tb_noc_router_5port -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/noc/noc_router_5port.sv ../tb/unit_tb/tb_noc_router_5port.sv -top tb_noc_router_5port

# 8. tb_noc_mesh_10x10
# irun -sv -64bit -access +rwc -coverage all -covdut noc_mesh_2d_10x10 -covworkdir ./cov_work -covtest tb_noc_mesh_10x10 -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/noc/*.sv ../tb/unit_tb/tb_noc_mesh_10x10.sv -top tb_noc_mesh_10x10

# 9. tb_axi_dma_controller
# irun -sv -64bit -access +rwc -coverage all -covdut axi_dma_controller -covworkdir ./cov_work -covtest tb_axi_dma_controller -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/memory/axi_dma_controller.sv ../tb/unit_tb/tb_axi_dma_controller.sv -top tb_axi_dma_controller

# 10. tb_agent_dag_scheduler
# irun -sv -64bit -access +rwc -coverage all -covdut agent_dag_scheduler -covworkdir ./cov_work -covtest tb_agent_dag_scheduler -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/agentic/agent_dag_scheduler.sv ../tb/unit_tb/tb_agent_dag_scheduler.sv -top tb_agent_dag_scheduler

# 11. tb_paged_kv_cache_mgr
# irun -sv -64bit -access +rwc -coverage all -covdut paged_kv_cache_mgr -covworkdir ./cov_work -covtest tb_paged_kv_cache_mgr -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/agentic/paged_kv_cache_mgr.sv ../tb/unit_tb/tb_paged_kv_cache_mgr.sv -top tb_paged_kv_cache_mgr

# 12. tb_agentic_coprocessor
# irun -sv -64bit -access +rwc -coverage all -covdut agentic_coprocessor_top -covworkdir ./cov_work -covtest tb_agentic_coprocessor -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/agentic/*.sv ../rtl/noc/noc_router_5port.sv ../tb/unit_tb/tb_agentic_coprocessor.sv -top tb_agentic_coprocessor

# 13. tb_riscv_ai_gpu_top (Full-Chip 100-Core ASIC SoC)
# irun -sv -64bit -access +rwc -coverage all -covdut riscv_ai_gpu_top -covworkdir ./cov_work -covtest tb_riscv_ai_gpu_top -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/core/*.sv ../rtl/neural/*.sv ../rtl/agentic/*.sv ../rtl/noc/*.sv ../rtl/cluster/*.sv ../rtl/memory/*.sv ../rtl/top/*.sv ../tb/integration_tb/tb_riscv_ai_gpu_top.sv -top tb_riscv_ai_gpu_top

echo "To run any simulation, execute the command from inside the 'work/' directory on the EDA server."
