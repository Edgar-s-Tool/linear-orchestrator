# Login autostart: start linear-orchestrator in background if not already listening.
# Installed via Windows Startup folder (no admin required).
param([int]$Port = 8645)

$ErrorActionPreference = "SilentlyContinue"
$root = Split-Path $PSScriptRoot -Parent
$venvPy = Join-Path $root ".venv\Scripts\python.exe"

if (-not (Test-Path $venvPy)) { exit 1 }

$listening = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($listening) { exit 0 }

$envFile = Join-Path $env:USERPROFILE ".hermes\.env"
$envVars = @{}
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
      $envVars[$matches[1]] = $matches[2]
    }
  }
}
if (-not $envVars['HERMES_PATH']) {
  $defaultHermes = Join-Path $env:LOCALAPPDATA "hermes\hermes-agent\venv\Scripts\hermes.exe"
  if (Test-Path $defaultHermes) { $envVars['HERMES_PATH'] = $defaultHermes }
}
$envVars['ORCHESTRATOR_PORT'] = "$Port"

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $venvPy
$psi.Arguments = "-m linear_orchestrator"
$psi.WorkingDirectory = $root
$psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
$psi.CreateNoWindow = $true
foreach ($kv in $envVars.GetEnumerator()) {
  $psi.Environment[$kv.Key] = $kv.Value
}
[System.Diagnostics.Process]::Start($psi) | Out-Null
