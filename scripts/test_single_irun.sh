#!/bin/bash
export CDS_AUTO_64BIT=ALL
source /home/ece-server/cadance_install/cshrc 2>/dev/null
cd /mnt/rl-home/THIRU/syn_workshop/riscv_ai_gpu
echo "run; exit" | irun -clean -sv -access +rwc -incdir ./rtl/include ./rtl/include/riscv_ai_gpu_pkg.sv ./rtl/include/agentic_isa_defs.sv ./rtl/agentic/agent_tree_search_engine.sv ./tb/unit_tb/tb_agent_tree_search.sv
