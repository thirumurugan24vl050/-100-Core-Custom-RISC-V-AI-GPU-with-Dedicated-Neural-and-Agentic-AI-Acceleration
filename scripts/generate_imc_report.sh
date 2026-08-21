#!/bin/bash
#=============================================================================
# Generate IMC Coverage Report
#=============================================================================
cd /mnt/rl-home/THIRU/syn_workshop/riscv_ai_gpu/work || exit 1
source ../scripts/setup_cadence_env.sh

rm -rf coverage_summary

cat << 'EOF' > imc_report.cmd
load -run cov_work/scope/tb_riscv_ai_gpu_top
report_metrics -detail -both -overwrite -out coverage_summary
EOF

imc -64bit -exec imc_report.cmd || true
cat coverage_summary/index.html 2>/dev/null | grep -E "Overall|Grade|Covered" | head -n 30 || true
