# Start linear-orchestrator on Windows (no WSL).
# Loads secrets from %USERPROFILE%\.hermes\.env
param(
  [int]$Port = 8645
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent

$venvPy = Join-Path $root ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPy)) {
  Write-Host "Missing venv. Run: cd $root; python -m venv .venv; .\.venv\Scripts\pip install -e ."
  exit 1
}

$envFile = Join-Path $env:USERPROFILE ".hermes\.env"
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
      [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
    }
  }
}

if (-not $env:HERMES_PATH) {
  $defaultHermes = Join-Path $env:LOCALAPPDATA "hermes\hermes-agent\venv\Scripts\hermes.exe"
  if (Test-Path $defaultHermes) {
    $env:HERMES_PATH = $defaultHermes
  }
}

$env:ORCHESTRATOR_PORT = "$Port"
Write-Host "Starting linear-orchestrator on http://127.0.0.1:$Port/ (HERMES_PATH=$($env:HERMES_PATH))"
Set-Location $root
& $venvPy -m linear_orchestrator
