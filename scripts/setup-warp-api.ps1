# Warp Oz API 一鍵設定與檢查（Windows）
# 給沒有科技背景的使用者：雙擊或在 PowerShell 執行此腳本即可。
param(
  [switch]$CreateApiKeyIfMissing
)

$ErrorActionPreference = "Stop"
$WarpExe = Join-Path ${env:ProgramFiles} "Warp\warp.exe"
$env:WARP_CLI_MODE = "1"
$env:WARP_OUTPUT_FORMAT = "json"

function Write-Step([string]$Title) {
  Write-Host ""
  Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Ensure-WarpApiKey {
  $key = [Environment]::GetEnvironmentVariable("WARP_API_KEY", "User")
  if ($key) {
    Write-Host "WARP_API_KEY 已存在（尾碼 ...$($key.Substring($key.Length - 4))）" -ForegroundColor Green
    return $key
  }

  if (-not $CreateApiKeyIfMissing) {
    throw @"
尚未設定 WARP_API_KEY。
請重新執行：
  .\scripts\setup-warp-api.ps1 -CreateApiKeyIfMissing
或在 oz.warp.dev → Settings → API Keys 手動建立後，執行：
  [Environment]::SetEnvironmentVariable('WARP_API_KEY', 'wk-...', 'User')
"@
  }

  if (-not (Test-Path $WarpExe)) {
    throw "找不到 Warp：$WarpExe"
  }

  Write-Host "正在建立新的 API 金鑰（edgar-cursor-automation）..." -ForegroundColor Yellow
  $raw = & $WarpExe api-key create --no-expiration "edgar-cursor-automation" 2>&1 | Out-String
  $obj = $raw | ConvertFrom-Json
  $key = $obj.raw_api_key
  [Environment]::SetEnvironmentVariable("WARP_API_KEY", $key, "User")
  Write-Host "已寫入 Windows 使用者環境變數 WARP_API_KEY" -ForegroundColor Green
  return $key
}

if (-not (Test-Path $WarpExe)) {
  throw "請先安裝 Warp 終端機：https://www.warp.dev/"
}

Write-Step "1. 確認 Warp 登入"
$who = & $WarpExe whoami | ConvertFrom-Json
Write-Host "帳號：$($who.display_name) <$($who.email)>"
Write-Host "團隊：$($who.team_name)"

Write-Step "2. API 金鑰"
$apiKey = Ensure-WarpApiKey
$env:WARP_API_KEY = $apiKey

Write-Step "3. 測試 Warp API"
$headers = @{ Authorization = "Bearer $apiKey" }
$runs = Invoke-RestMethod -Uri "https://app.warp.dev/api/v1/agent/runs?limit=1" -Headers $headers
Write-Host "API 連線成功。最近任務數：$($runs.runs.Count)" -ForegroundColor Green

Write-Step "4. 雲端環境（Environment）"
$envs = & $WarpExe environment list | ConvertFrom-Json
foreach ($e in $envs) {
  $repos = ($e.github_repos | ForEach-Object { "$($_.owner)/$($_.repo)" }) -join ", "
  Write-Host "- $($e.name) [$($e.id)]"
  Write-Host "  Docker: $($e.base_image.docker_image)"
  Write-Host "  Repo: $repos"
}

Write-Step "5. 整合（Integration）"
$integrations = & $WarpExe integration list | ConvertFrom-Json
foreach ($i in $integrations) {
  $color = if ($i.status -match "connected") { "Green" } else { "Yellow" }
  Write-Host "- $($i.provider): $($i.status)" -ForegroundColor $color
}

Write-Step "完成 — 你現在可以這樣用"
Write-Host @"
1) 叫 Warp 幫你做一件事（本機腳本）：
   cd V:\projects\linear-orchestrator
   .\scripts\ask-warp.ps1 -Prompt "掃描 repo 並列出 README 重點"

2) 在 Linear 裡把 issue 指派給 Oz（Delegate → Oz）
   環境：edgar-linear-dev（linear-orchestrator）

3) 在網頁看任務：
   https://oz.warp.dev
"@
