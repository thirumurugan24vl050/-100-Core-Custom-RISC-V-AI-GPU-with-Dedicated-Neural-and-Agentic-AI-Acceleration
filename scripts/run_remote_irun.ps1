#=============================================================================
# PowerShell Remote EDA Launcher: Cadence irun Execution on Linux Server
# Server: 192.168.1.100 (synopsys.siet.ac.in)
# User: THIRU
#=============================================================================

param(
    [string]$ServerIP = "192.168.1.100",
    [string]$Username = "THIRU",
    [string]$Password = "siet@2922",
    [string]$RemoteDir = "/mnt/rl-home/THIRU/syn_workshop/riscv_ai_gpu"
)

$PLINK = "C:\Program Files\PuTTY\plink.exe"
$PSCP  = "C:\Program Files\PuTTY\pscp.exe"
$HOSTKEY = "ssh-ed25519 255 SHA256:OdMIOLkQlJTYMyb5cA/0W4LLRHKrANTlzQAiogIZn0U"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " [REMOTE CADENCE IRUN] Syncing Codebase to $Username@$ServerIP..." -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Create Remote Directory
& $PLINK -ssh -batch -hostkey $HOSTKEY -l $Username -pw $Password $ServerIP "mkdir -p $RemoteDir"

# 2. Upload RTL, TB, Docs, Scripts
& $PSCP -batch -hostkey $HOSTKEY -pw $Password -r rtl tb docs scripts README.md "$($Username)@$($ServerIP):$($RemoteDir)/"

# 3. Execute irun on Linux Server
Write-Host "`n================================================================================" -ForegroundColor Yellow
Write-Host " [REMOTE CADENCE IRUN] Launching Cadence irun Regression on Linux Server..." -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Yellow

$RemoteCmd = "cd $RemoteDir; chmod +x scripts/*.sh; bash scripts/run_irun.sh"
& $PLINK -ssh -batch -hostkey $HOSTKEY -l $Username -pw $Password $ServerIP $RemoteCmd
