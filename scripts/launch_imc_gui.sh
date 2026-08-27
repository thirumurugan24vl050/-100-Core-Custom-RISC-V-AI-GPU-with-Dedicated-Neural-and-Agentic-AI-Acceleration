#!/bin/bash
#=============================================================================
# Script to launch Cadence Integrated Metrics Center (IMC) Coverage GUI
# Usage on Server (Terminal / VNC / X11): bash scripts/launch_imc_gui.sh
#=============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup_cadence_env.sh" 2>/dev/null || true

cd "$SCRIPT_DIR/../work" 2>/dev/null || cd "$SCRIPT_DIR/.."

echo "Launching Cadence IMC Coverage GUI with merged coverage database..."
if [ -d "./cov_work/scope/merged_cov" ]; then
    imc -64bit -load ./cov_work/scope/merged_cov &
elif [ -d "../cov_work/scope/merged_cov" ]; then
    imc -64bit -load ../cov_work/scope/merged_cov &
else
    imc -64bit &
fi
