#!/bin/bash
#=============================================================================
# Persistent Background Regression Runner (Runs even if PC disconnects)
#=============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$SCRIPT_DIR/../logs" "$SCRIPT_DIR/../work"

nohup bash "$SCRIPT_DIR/run_work_regression.sh" > "$SCRIPT_DIR/../logs/full_regression_$(date +%Y%m%d_%H%M%S).log" 2>&1 &
REG_PID=$!

echo "================================================================================"
echo " [CADENCE BACKGROUND RUNNER] Regression launched with PID: $REG_PID"
echo " Log file: logs/full_regression_*.log"
echo " The process is running in the background and will continue even if PC is OFF."
echo "================================================================================"
