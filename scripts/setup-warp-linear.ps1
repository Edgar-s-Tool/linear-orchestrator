# Warp Oz + Linear integration setup (Windows-native).
# Docs: https://docs.warp.dev/agent-platform/cloud-agents/integrations/linear/
#       https://docs.warp.dev/reference/cli/integration-setup/
param(
  [string]$EnvironmentId = "gMtdQHl184AFGV1DgM8eLk",
  [string]$EnvironmentName = "edgar-linear-dev"
)

$ErrorActionPreference = "Stop"
$warp = Join-Path ${env:ProgramFiles} "Warp\warp.exe"
if (-not (Test-Path $warp)) { throw "Warp not found at $warp" }

$env:WARP_CLI_MODE = "1"

Write-Host "=== Warp Oz environments ===" -ForegroundColor Cyan
& $warp environment list

if (-not $EnvironmentId) {
  Write-Host "Creating environment $EnvironmentName ..." -ForegroundColor Cyan
  & $warp environment create `
    --name $EnvironmentName `
    --docker-image python:3.11 `
    --repo Edgar-s-Tool/linear-orchestrator `
    --setup-command "pip install -e ." `
    --description "Linear orchestrator dev env for Oz triggers"
  Write-Host "Copy the Environment ID from the table above into -EnvironmentId next time."
}

Write-Host ""
Write-Host "=== Connect Linear (opens browser — complete OAuth in Linear) ===" -ForegroundColor Yellow
Write-Host "Per Warp docs: Linear email must match Warp account (edgar@edgarbeyourself.com)"
Start-Process "https://oz.warp.dev"
& $warp integration create linear --environment $EnvironmentId

Write-Host ""
Write-Host "=== Verify ===" -ForegroundColor Cyan
& $warp integration list
