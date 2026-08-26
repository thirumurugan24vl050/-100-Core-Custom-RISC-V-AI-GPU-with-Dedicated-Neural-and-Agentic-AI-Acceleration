#!/bin/bash
#=============================================================================
# Single Test Runner with Cadence irun & IMC Coverage
#=============================================================================
source ../scripts/setup_cadence_env.sh

TEST_NAME=$1
DUT_NAME=$2
RTL_FILES=$3
TB_FILE=$4

echo "================================================================================"
echo " [RUNNING TEST] $TEST_NAME on DUT: $DUT_NAME"
echo "================================================================================"

irun -sv -64bit -access +rwc \
     -coverage all \
     -covdut "$DUT_NAME" \
     -covworkdir ./cov_work \
     -covtest "$TEST_NAME" \
     -covoverwrite \
     -input ../scripts/sim.tcl \
     -incdir ../rtl/include \
     ../rtl/include/riscv_ai_gpu_pkg.sv \
     $RTL_FILES \
     $TB_FILE \
     -top "$TEST_NAME"

RET=$?
if [ $RET -eq 0 ]; then
    echo "================================================================================"
    echo " [TEST PASSED] $TEST_NAME PASSED WITH 0 ERRORS"
    echo "================================================================================"
else
    echo "================================================================================"
    echo " [TEST FAILED] $TEST_NAME FAILED WITH EXIT CODE $RET"
    echo "================================================================================"
fi
exit $RET
