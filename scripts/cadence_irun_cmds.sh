#!/bin/bash
#=============================================================================
# Cadence Incisive (irun) Master Command Reference & Suite
# Design: 100-Core Custom RISC-V SIMT AI GPU (Production V1)
# Location: /mnt/rl-home/THIRU/syn_workshop/riscv_ai_gpu
#=============================================================================

source ./scripts/setup_cadence_env.sh 2>/dev/null || true

echo "================================================================================"
echo " CADENCE IRUN COMMAND REFERENCE SUITE (13 PRODUCTION V1 ENVIRONMENTS)"
echo "================================================================================"

# 1. tb_riscv_ai_core
irun -sv -64bit -access +rwc -coverage all -covdut riscv_ai_core -covworkdir ./cov_work -covtest tb_riscv_ai_core -covoverwrite -incdir ./rtl/include -f ./scripts/rtl_files.f ./tb/unit_tb/tb_riscv_ai_core.sv -top tb_riscv_ai_core -run -exit

# 2. tb_neural_systolic_engine
irun -sv -64bit -access +rwc -coverage all -covdut neural_systolic_engine_8x8 -covworkdir ./cov_work -covtest tb_neural_systolic_engine -covoverwrite -incdir ./rtl/include -f ./scripts/rtl_files.f ./tb/unit_tb/tb_neural_systolic_engine.sv -top tb_neural_systolic_engine -run -exit

# 3. tb_neural_postproc
irun -sv -64bit -access +rwc -coverage all -covdut neural_postproc_unit -covworkdir ./cov_work -covtest tb_neural_postproc -covoverwrite -incdir ./rtl/include -f ./scripts/rtl_files.f ./tb/unit_tb/tb_neural_postproc.sv -top tb_neural_postproc -run -exit

# 4. tb_neural_softmax
irun -sv -64bit -access +rwc -coverage all -covdut neural_softmax_unit -covworkdir ./cov_work -covtest tb_neural_softmax -covoverwrite -incdir ./rtl/include -f ./scripts/rtl_files.f ./tb/unit_tb/tb_neural_softmax.sv -top tb_neural_softmax -run -exit

# 5. tb_cluster_scratchpad
irun -sv -64bit -access +rwc -coverage all -covdut cluster_scratchpad_sram -covworkdir ./cov_work -covtest tb_cluster_scratchpad -covoverwrite -incdir ./rtl/include -f ./scripts/rtl_files.f ./tb/unit_tb/tb_cluster_scratchpad.sv -top tb_cluster_scratchpad -run -exit

# 6. tb_cluster_barrier
irun -sv -64bit -access +rwc -coverage all -covdut cluster_barrier_sync -covworkdir ./cov_work -covtest tb_cluster_barrier -covoverwrite -incdir ./rtl/include -f ./scripts/rtl_files.f ./tb/unit_tb/tb_cluster_barrier.sv -top tb_cluster_barrier -run -exit

# 7. tb_noc_router_5port
irun -sv -64bit -access +rwc -coverage all -covdut noc_router_5port -covworkdir ./cov_work -covtest tb_noc_router_5port -covoverwrite -incdir ./rtl/include -f ./scripts/rtl_files.f ./tb/unit_tb/tb_noc_router_5port.sv -top tb_noc_router_5port -run -exit

# 8. tb_noc_mesh_10x10
irun -sv -64bit -access +rwc -coverage all -covdut noc_mesh_2d_10x10 -covworkdir ./cov_work -covtest tb_noc_mesh_10x10 -covoverwrite -incdir ./rtl/include -f ./scripts/rtl_files.f ./tb/unit_tb/tb_noc_mesh_10x10.sv -top tb_noc_mesh_10x10 -run -exit

# 9. tb_axi_dma_controller
irun -sv -64bit -access +rwc -coverage all -covdut axi_dma_controller -covworkdir ./cov_work -covtest tb_axi_dma_controller -covoverwrite -incdir ./rtl/include -f ./scripts/rtl_files.f ./tb/unit_tb/tb_axi_dma_controller.sv -top tb_axi_dma_controller -run -exit

# 10. tb_agent_dag_scheduler
irun -sv -64bit -access +rwc -coverage all -covdut agent_dag_scheduler -covworkdir ./cov_work -covtest tb_agent_dag_scheduler -covoverwrite -incdir ./rtl/include -f ./scripts/rtl_files.f ./tb/unit_tb/tb_agent_dag_scheduler.sv -top tb_agent_dag_scheduler -run -exit

# 11. tb_paged_kv_cache_mgr
irun -sv -64bit -access +rwc -coverage all -covdut paged_kv_cache_mgr -covworkdir ./cov_work -covtest tb_paged_kv_cache_mgr -covoverwrite -incdir ./rtl/include -f ./scripts/rtl_files.f ./tb/unit_tb/tb_paged_kv_cache_mgr.sv -top tb_paged_kv_cache_mgr -run -exit

# 12. tb_agentic_coprocessor
irun -sv -64bit -access +rwc -coverage all -covdut agentic_coprocessor_top -covworkdir ./cov_work -covtest tb_agentic_coprocessor -covoverwrite -incdir ./rtl/include -f ./scripts/rtl_files.f ./tb/unit_tb/tb_agentic_coprocessor.sv -top tb_agentic_coprocessor -run -exit

# 13. tb_riscv_ai_gpu_top (Full-Chip 100-Core ASIC SoC)
irun -sv -64bit -access +rwc -coverage all -covdut riscv_ai_gpu_top -covworkdir ./cov_work -covtest tb_riscv_ai_gpu_top -covoverwrite -incdir ./rtl/include -f ./scripts/rtl_files.f ./tb/integration_tb/tb_riscv_ai_gpu_top.sv -top tb_riscv_ai_gpu_top -run -exit

echo "All 13 simulation commands defined."
