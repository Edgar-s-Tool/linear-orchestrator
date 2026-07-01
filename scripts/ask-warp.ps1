# 用白話叫 Warp 雲端 AI 做事（不需懂 API）
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Prompt,

  [ValidateSet("linear", "deploy", "general")]
  [string]$Project = "linear",

  [switch]$Wait
)

$ErrorActionPreference = "Stop"

$Environments = @{
  linear  = @{ Id = "gMtdQHl184AFGV1DgM8eLk"; Name = "edgar-linear-dev" }
  deploy  = @{ Id = "24syFwqAf4M1SUPXZWEywM"; Name = "deploy-pilot" }
  general = @{ Id = "C0onm8hL5yAcFPJO85EDp6"; Name = "new world" }
}

$apiKey = [Environment]::GetEnvironmentVariable("WARP_API_KEY", "User")
if (-not $apiKey) {
  throw "尚未設定 WARP_API_KEY。請先執行：.\scripts\setup-warp-api.ps1 -CreateApiKeyIfMissing"
}

$envInfo = $Environments[$Project]
Write-Host "送出任務到 $($envInfo.Name) ..." -ForegroundColor Cyan
Write-Host "指令：$Prompt"
Write-Host ""

$body = @{
  prompt = $Prompt
  title  = "Cursor/Windows: $($Prompt.Substring(0, [Math]::Min(60, $Prompt.Length)))"
  config = @{
    environment_id = $envInfo.Id
    name           = $envInfo.Name
  }
} | ConvertTo-Json -Depth 5

$headers = @{
  Authorization  = "Bearer $apiKey"
  "Content-Type" = "application/json"
}

$response = Invoke-RestMethod `
  -Uri "https://app.warp.dev/api/v1/agent/run" `
  -Method POST `
  -Headers $headers `
  -Body $body

$runId = $response.run_id
Write-Host "任務已建立！" -ForegroundColor Green
Write-Host "Run ID：$runId"
if ($response.session_link) {
  Write-Host "查看進度：$($response.session_link)"
}

if (-not $Wait) {
  Write-Host ""
  Write-Host "AI 在背景執行。若要等它跑完，下次加 -Wait 參數。" -ForegroundColor Yellow
  return
}

Write-Host ""
Write-Host "等待完成（每 15 秒查一次）..." -ForegroundColor Yellow
do {
  Start-Sleep -Seconds 15
  $run = Invoke-RestMethod `
    -Uri "https://app.warp.dev/api/v1/agent/runs/$runId" `
    -Headers @{ Authorization = "Bearer $apiKey" }
  Write-Host "狀態：$($run.state) — $($run.updated_at)"
} while ($run.state -in @("QUEUED", "INPROGRESS"))

if ($run.state -eq "SUCCEEDED") {
  Write-Host "完成！" -ForegroundColor Green
  Write-Host "結果頁：$($run.session_link)"
} else {
  Write-Host "未成功：$($run.state)" -ForegroundColor Red
  if ($run.status_message) { Write-Host $run.status_message }
}
