$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$startScript = Join-Path $repoRoot "scripts\Start-LinearOrchestrator.ps1"
$logDir = Join-Path "G:\AI_WORK_512\run" "linear-orchestrator"
$bootstrapLog = Join-Path $logDir "login-bootstrap.log"

New-Item -ItemType Directory -Force -Path $logDir | Out-Null

function Write-BootstrapLog {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -LiteralPath $bootstrapLog -Value "[$timestamp] $Message"
}

try {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"

    if (-not (Test-Path -LiteralPath $startScript)) {
        Write-BootstrapLog "Missing start script: $startScript"
        exit 1
    }

    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $startScript,
        "-Wait"
    )
    Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList $args `
        -WorkingDirectory $repoRoot `
        -WindowStyle Hidden

    Write-BootstrapLog "Triggered Start-LinearOrchestrator.ps1 at logon."
}
catch {
    Write-BootstrapLog "Startup failed: $($_.Exception.Message)"
    exit 1
}
