#!/bin/bash
#=============================================================================
# Cadence IMC Coverage Report Generation Script
#=============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup_cadence_env.sh" 2>/dev/null || true

echo "================================================================================"
echo " [CADENCE IMC] Generating Unified Coverage Report..."
echo "================================================================================"

rm -rf coverage_merged_report merged_cov

cat << 'EOF' > merge_cov.cmd
merge cov_work/scope/* -out merged_cov -overwrite
load -run merged_cov
report_metrics -detail -both -overwrite -out coverage_merged_report
EOF

imc -64bit -exec merge_cov.cmd

echo ""
echo "Coverage report generated under: $(pwd)/coverage_merged_report"
