param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "LinearOrchestratorCommon.psm1") -Force

$repoRoot = Get-OrchestratorRepoRoot
$venvPython = Join-Path $repoRoot ".venv\Scripts\python.exe"

Write-Host "[1/3] Creating Windows venv at $repoRoot\.venv"
if (-not (Test-Path -LiteralPath $venvPython)) {
    $py = Get-Command python -ErrorAction Stop
    & $py.Source -m venv (Join-Path $repoRoot ".venv")
}

Write-Host "[2/3] Installing linear-orchestrator (editable)"
& $venvPython -m pip install --upgrade pip | Out-Null
& $venvPython -m pip install -e $repoRoot

Write-Host "[3/3] Sanity import"
& $venvPython -c "from linear_orchestrator.server import make_app; print('import ok')"

Write-Host ""
Write-Host "DONE. Next:"
Write-Host "  powershell -ExecutionPolicy Bypass -File scripts\Start-LinearOrchestrator.ps1"
Write-Host "  powershell -ExecutionPolicy Bypass -File scripts\Check-LinearOrchestrator.ps1"
