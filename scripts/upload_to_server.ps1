#=============================================================================
# Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
# File: upload_to_server.ps1
# Description: Clean Automated Sync to EDA Server (192.168.1.100: syn_workshop/riscv_ai_gpu)
#=============================================================================

$PSCP = "C:\Program Files\PuTTY\pscp.exe"
$PLINK = "C:\Program Files\PuTTY\plink.exe"
$HOSTKEY = "SHA256:OdMIOLkQlJTYMyb5cA/0W4LLRHKrANTlzQAiogIZn0U"
$USER = "THIRU"
$PASS = "siet@2922"
$SERVER = "192.168.1.100"
$REMOTE_DIR = "/mnt/rl-home/THIRU/syn_workshop/riscv_ai_gpu"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " [SERVER SYNC] Purging Obsolete Files & Uploading Clean Codebase to ${USER}@${SERVER}" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Clean obsolete files & temp logs on server
Write-Host " [*] Purging obsolete files and logs from server..." -ForegroundColor Yellow
& $PLINK -batch -hostkey $HOSTKEY -ssh -l $USER -pw $PASS $SERVER "cd $REMOTE_DIR && rm -rf INCA_libs xcelium.d cov_work *.err *.log *.history cluster_imem_gen.sv riscv_ai_gpu_top.sv tb_riscv_ai_gpu_top.sv rtl/ tb/ && mkdir -p rtl/include rtl/core rtl/neural rtl/cluster rtl/noc rtl/memory rtl/agentic rtl/top tb/unit_tb tb/integration_tb scripts docs work"

# 2. Upload RTL directory
Write-Host " [*] Uploading rtl/ subsystem..." -ForegroundColor Yellow
& $PSCP -batch -hostkey $HOSTKEY -pw $PASS -r rtl/* "${USER}@${SERVER}:${REMOTE_DIR}/rtl/"

# 3. Upload TB directory
Write-Host " [*] Uploading tb/ subsystem..." -ForegroundColor Yellow
& $PSCP -batch -hostkey $HOSTKEY -pw $PASS -r tb/* "${USER}@${SERVER}:${REMOTE_DIR}/tb/"

# 4. Upload scripts directory
Write-Host " [*] Uploading scripts/ subsystem..." -ForegroundColor Yellow
& $PSCP -batch -hostkey $HOSTKEY -pw $PASS -r scripts/* "${USER}@${SERVER}:${REMOTE_DIR}/scripts/"

# 5. Upload docs and README
Write-Host " [*] Uploading docs/ and README.md..." -ForegroundColor Yellow
& $PSCP -batch -hostkey $HOSTKEY -pw $PASS -r docs/* "${USER}@${SERVER}:${REMOTE_DIR}/docs/"
& $PSCP -batch -hostkey $HOSTKEY -pw $PASS README.md "${USER}@${SERVER}:${REMOTE_DIR}/"

# 6. Set execute permissions and verify on server
Write-Host " [*] Setting permissions and verifying files on server..." -ForegroundColor Yellow
& $PLINK -batch -hostkey $HOSTKEY -ssh -l $USER -pw $PASS $SERVER "cd $REMOTE_DIR && chmod +x scripts/*.sh && ls -la && echo '--- RTL Inventory ---' && find rtl/ -type f | sort && echo '--- TB Inventory ---' && find tb/ -type f | sort"

Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Green
Write-Host " [SUCCESS] Server Upload & Clean Synchronization Complete!" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
