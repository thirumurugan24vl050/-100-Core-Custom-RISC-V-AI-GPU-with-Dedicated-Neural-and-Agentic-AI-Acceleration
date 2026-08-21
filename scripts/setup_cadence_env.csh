#=============================================================================
# Cadence Environment Setup for CSH / TCSH
# Server: synopsys.siet.ac.in
#=============================================================================

setenv CDS_Netlisting_Mode Analog
setenv QRC_ENABLE_QRCRACTION 1
setenv CDS_AUTO_64BIT ALL
setenv CDS_AHDLCMI_ENABLE YES
setenv LM_LICENSE_FILE "5280@14.139.1.126:1717@14.139.1.126:27020@14.139.1.126"
setenv MGLS_LICENSE_FILE "1717@14.139.1.126"
setenv CDS_LIC_FILE "$LM_LICENSE_FILE"
setenv LANG en_US

setenv IUSHOME /home/ece-server/cadance_install/INCISIVE152
setenv XCELIUMHOME /home/ece-server/cadance_install/XCELIUM2209
setenv GENUSHOME /home/ece-server/cadance_install/GENUS211
setenv INNOVUSHOME /home/ece-server/cadance_install/INNOVUS211
setenv CDSHOME /home/ece-server/cadance_install/IC618/IC618

setenv PATH ${IUSHOME}/bin:${IUSHOME}/tools.lnx86/bin:${XCELIUMHOME}/bin:${XCELIUMHOME}/tools/bin:${GENUSHOME}/bin:${INNOVUSHOME}/bin:${PATH}
if ( $?LD_LIBRARY_PATH ) then
    setenv LD_LIBRARY_PATH /usr/lib64:/opt/cadence/lib:${IUSHOME}/tools/lib:${LD_LIBRARY_PATH}
else
    setenv LD_LIBRARY_PATH /usr/lib64:/opt/cadence/lib:${IUSHOME}/tools/lib
endif
