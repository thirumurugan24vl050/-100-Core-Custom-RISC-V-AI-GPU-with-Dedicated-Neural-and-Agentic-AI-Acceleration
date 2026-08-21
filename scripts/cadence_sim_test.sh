#!/bin/bash
source /mnt/rl-home/THIRU/syn_workshop/riscv_ai_gpu/scripts/setup_cadence_env.sh
cd /mnt/rl-home/THIRU/syn_workshop/riscv_ai_gpu
cat << 'EOF' > sim_cmd.tcl
run
exit
EOF
xmsim worklib.tb_agent_tree_search:sv -input sim_cmd.tcl
