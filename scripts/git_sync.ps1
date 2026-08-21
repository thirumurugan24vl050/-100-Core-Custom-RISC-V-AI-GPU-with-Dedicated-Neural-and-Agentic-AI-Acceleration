#=============================================================================
# Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
# File: git_sync.ps1
# Description: Automated Git commit and push sync script.
#=============================================================================

param(
    [string]$CommitMessage = "update: sync RTL, testbenches, and documentation updates",
    [string]$GithubToken = ""
)

$GIT = "c:\Users\vlsilab\tools\git\cmd\git.exe"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " [GIT SYNC] Staging & Committing Codebase..." -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

& $GIT add .gitignore rtl tb docs scripts README.md
& $GIT status

$status = & $GIT status --porcelain
if ($status) {
    & $GIT commit -m $CommitMessage
    Write-Host " [GIT] Changes committed successfully." -ForegroundColor Green
} else {
    Write-Host " [GIT] No new changes to commit." -ForegroundColor Yellow
}

if ($GithubToken -ne "") {
    Write-Host " [GIT] Authenticating and pushing to origin with token..." -ForegroundColor Yellow
    $RemoteUrl = "https://$($GithubToken)@github.com/thirumurugan24vl050/-100-Core-Custom-RISC-V-AI-GPU-with-Dedicated-Neural-and-Agentic-AI-Acceleration.git"
    & $GIT push $RemoteUrl main -f
} else {
    Write-Host "`n [NOTE] To push directly to your remote repository, run:" -ForegroundColor Magenta
    Write-Host "   .\scripts\git_sync.ps1 -GithubToken <YOUR_GITHUB_PERSONAL_ACCESS_TOKEN>" -ForegroundColor White
    Write-Host " Or run:" -ForegroundColor Magenta
    Write-Host "   c:\Users\vlsilab\tools\git\cmd\git.exe push -u origin main" -ForegroundColor White
}
