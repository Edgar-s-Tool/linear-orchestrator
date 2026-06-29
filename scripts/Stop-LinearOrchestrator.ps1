$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "LinearOrchestratorCommon.psm1") -Force

$proc = Get-OrchestratorProcess
if (-not $proc) {
    Write-Host "Not running (no valid PID file)."
    exit 0
}

Write-Host "Stopping pid=$($proc.Id) ..."
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

if (Test-Path -LiteralPath (Get-OrchestratorPidFile)) {
    Remove-Item -LiteralPath (Get-OrchestratorPidFile) -Force
}

Write-Host "Stopped."
