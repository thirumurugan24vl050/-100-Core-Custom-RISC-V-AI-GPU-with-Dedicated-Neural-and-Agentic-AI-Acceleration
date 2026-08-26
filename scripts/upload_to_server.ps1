#=============================================================================
# Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
# File: upload_to_server.ps1
# Description: Automated SCP Upload to EDA Server (192.168.1.100: syn_workshop/riscv_ai_gpu)
#=============================================================================

$PSCP = "C:\Program Files\PuTTY\pscp.exe"
$PLINK = "C:\Program Files\PuTTY\plink.exe"
$HOSTKEY = "SHA256:OdMIOLkQlJTYMyb5cA/0W4LLRHKrANTlzQAiogIZn0U"
$USER = "THIRU"
$PASS = "siet@2922"
$SERVER = "192.168.1.100"
$REMOTE_DIR = "/mnt/rl-home/THIRU/syn_workshop/riscv_ai_gpu"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " [SERVER SYNC] Uploading Production Codebase to ${USER}@${SERVER}:${REMOTE_DIR}" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Ensure remote directories exist
Write-Host " [*] Creating remote directory structure..." -ForegroundColor Yellow
& $PLINK -batch -hostkey $HOSTKEY -ssh -l $USER -pw $PASS $SERVER "mkdir -p $REMOTE_DIR/rtl/include $REMOTE_DIR/rtl/core $REMOTE_DIR/rtl/neural $REMOTE_DIR/rtl/cluster $REMOTE_DIR/rtl/noc $REMOTE_DIR/rtl/memory $REMOTE_DIR/rtl/agentic $REMOTE_DIR/rtl/top $REMOTE_DIR/tb/unit_tb $REMOTE_DIR/tb/cluster_tb $REMOTE_DIR/tb/integration_tb $REMOTE_DIR/scripts $REMOTE_DIR/docs $REMOTE_DIR/work"

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

# 6. Verify remote files on server
Write-Host " [*] Verifying uploaded files on server..." -ForegroundColor Yellow
& $PLINK -batch -hostkey $HOSTKEY -ssh -l $USER -pw $PASS $SERVER "cd $REMOTE_DIR && ls -la && ls -la rtl/ && ls -la scripts/"

Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Green
Write-Host " [SUCCESS] Server Upload to ${SERVER}:${REMOTE_DIR} Complete!" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
