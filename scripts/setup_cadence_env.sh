#!/bin/bash
#=============================================================================
# Cadence Environment Setup for bash
# Server: synopsys.siet.ac.in
#=============================================================================

export CDS_Netlisting_Mode=Analog
export QRC_ENABLE_QRCRACTION=1
export CDS_AUTO_64BIT=ALL
export CDS_AHDLCMI_ENABLE=YES
export LM_LICENSE_FILE="5280@14.139.1.126:1717@14.139.1.126:27020@14.139.1.126"
export MGLS_LICENSE_FILE="1717@14.139.1.126"
export CDS_LIC_FILE="$LM_LICENSE_FILE"
export LANG=en_US

export IUSHOME=/home/ece-server/cadance_install/INCISIVE152
export XCELIUMHOME=/home/ece-server/cadance_install/XCELIUM2209
export GENUSHOME=/home/ece-server/cadance_install/GENUS211
export INNOVUSHOME=/home/ece-server/cadance_install/INNOVUS211
export CDSHOME=/home/ece-server/cadance_install/IC618/IC618

export PATH=$IUSHOME/bin:$IUSHOME/tools.lnx86/bin:$XCELIUMHOME/bin:$XCELIUMHOME/tools/bin:$GENUSHOME/bin:$INNOVUSHOME/bin:$PATH
export LD_LIBRARY_PATH=/usr/lib64:/opt/cadence/lib:$IUSHOME/tools/lib:$LD_LIBRARY_PATH
