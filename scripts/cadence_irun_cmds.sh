#!/bin/bash
#=============================================================================
# Cadence Incisive (irun) Master Command Reference
# Design: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
# Location: /mnt/rl-home/THIRU/syn_workshop/riscv_ai_gpu/work
#=============================================================================

# Source environment
source ../scripts/setup_cadence_env.sh

echo "================================================================================"
echo " CADENCE IRUN COMMAND REFERENCE SUITE"
echo "================================================================================"

#-------------------------------------------------------------------------------
# [TEST 1] Core Scalar ALU & 256-bit Vector Unit (8 Subsystem Tests)
#-------------------------------------------------------------------------------
# Command:
# irun -sv -gui -access +rwc -coverage all -covdut riscv_ai_core -covworkdir ./cov_work -covtest tb_riscv_ai_core -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/core/*.sv ../tb/unit_tb/tb_riscv_ai_core.sv -top tb_riscv_ai_core

#-------------------------------------------------------------------------------
# [TEST 2] 8x8 INT8/FP16 Neural Systolic GEMM Engine (8 Subsystem Tests)
#-------------------------------------------------------------------------------
# Command:
# irun -sv -gui -access +rwc -coverage all -covdut neural_systolic_engine_8x8 -covworkdir ./cov_work -covtest tb_neural_systolic_engine -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/neural/*.sv ../tb/unit_tb/tb_neural_systolic_engine.sv -top tb_neural_systolic_engine

#-------------------------------------------------------------------------------
# [TEST 3] Neural Non-Linear Activation & Softmax LUT Pipeline (8 Tests)
#-------------------------------------------------------------------------------
# Command:
# irun -sv -gui -access +rwc -coverage all -covdut neural_activation_unit -covworkdir ./cov_work -covtest tb_neural_activation -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/neural/*.sv ../tb/unit_tb/tb_neural_activation.sv -top tb_neural_activation

#-------------------------------------------------------------------------------
# [TEST 4] Hardware Dynamic Agent DAG Task Scheduler (8 Tests)
#-------------------------------------------------------------------------------
# Command:
# irun -sv -gui -access +rwc -coverage all -covdut agent_dag_scheduler -covworkdir ./cov_work -covtest tb_agent_dag_scheduler -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/agentic/*.sv ../tb/unit_tb/tb_agent_dag_scheduler.sv -top tb_agent_dag_scheduler

#-------------------------------------------------------------------------------
# [TEST 5] Paged Attention KV-Cache Physical Page Table & Allocator (8 Tests)
#-------------------------------------------------------------------------------
# Command:
# irun -sv -gui -access +rwc -coverage all -covdut paged_kv_cache_mgr -covworkdir ./cov_work -covtest tb_paged_kv_cache_mgr -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/agentic/*.sv ../tb/unit_tb/tb_paged_kv_cache_mgr.sv -top tb_paged_kv_cache_mgr

#-------------------------------------------------------------------------------
# [TEST 6] Speculative Monte-Carlo Tree Search (MCTS/UCT) Engine (8 Tests)
#-------------------------------------------------------------------------------
# Command:
# irun -sv -gui -access +rwc -coverage all -covdut agent_tree_search_engine -covworkdir ./cov_work -covtest tb_agent_tree_search -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/agentic/*.sv ../tb/unit_tb/tb_agent_tree_search.sv -top tb_agent_tree_search

#-------------------------------------------------------------------------------
# [TEST 7] 5-Port Virtual-Channel XY Dimension-Order NoC Router (8 Tests)
#-------------------------------------------------------------------------------
# Command:
# irun -sv -gui -access +rwc -coverage all -covdut noc_router_5port -covworkdir ./cov_work -covtest tb_noc_router_5port -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/noc/*.sv ../tb/unit_tb/tb_noc_router_5port.sv -top tb_noc_router_5port

#-------------------------------------------------------------------------------
# [TEST 8] 10-Core AI GPU Cluster Subsystem & Banked Scratchpad (8 Tests)
#-------------------------------------------------------------------------------
# Command:
# irun -sv -gui -access +rwc -coverage all -covdut ai_gpu_cluster -covworkdir ./cov_work -covtest tb_ai_gpu_cluster -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/core/*.sv ../rtl/neural/*.sv ../rtl/noc/*.sv ../rtl/cluster/*.sv ../tb/cluster_tb/tb_ai_gpu_cluster.sv -top tb_ai_gpu_cluster

#-------------------------------------------------------------------------------
# [MASTER FULL-CHIP TEST] 100-Core Top-Level ASIC SoC (20 Rigorous Tests TC01-TC20)
#-------------------------------------------------------------------------------
# Command:
# irun -sv -gui -access +rwc -coverage all -covdut riscv_ai_gpu_top -covworkdir ./cov_work -covtest tb_riscv_ai_gpu_top -covoverwrite -incdir ../rtl/include ../rtl/include/riscv_ai_gpu_pkg.sv ../rtl/core/*.sv ../rtl/neural/*.sv ../rtl/agentic/*.sv ../rtl/noc/*.sv ../rtl/cluster/*.sv ../rtl/memory/*.sv ../rtl/top/*.sv ../tb/top_tb/tb_riscv_ai_gpu_top.sv -top tb_riscv_ai_gpu_top

echo "Run any command above inside the 'work/' directory on the EDA server."
