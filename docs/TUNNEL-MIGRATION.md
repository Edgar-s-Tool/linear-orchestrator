# Tunnel migration: webhook → Windows localhost:8645

最後更新：2026-06-30

## 現況（Windows 原生）

- **linear-orchestrator** 跑在 **Windows** `0.0.0.0:8645`（不是 WSL）
- `http://127.0.0.1:8645/healthz` 本機應回 200
- **Cloudflared** 以 Windows 服務跑 `edgar-local-01-tunnel`（token-based，Dashboard 管路由）

Linear webhook 進不來通常是：

1. Dashboard tunnel 裡 `webhook.whoasked.vip` 還指 **localhost:8644**（舊 hermes gateway）或 **WSL IP:8645**
2. orchestrator 沒在 Windows 跑

## 一步修好：改 dashboard route

1. 開 <https://one.dash.cloudflare.com/> → **Networks → Tunnels → edgar-local-01-tunnel → Public Hostname**
2. 找 `webhook.whoasked.vip`
3. Service 改成 **`http://localhost:8645`**
4. 存檔 → 等幾秒 → `https://webhook.whoasked.vip/healthz` 應 200

> **不要**再用 `http://172.30.x.x:8645`。WSL 已退出這條路。

## 啟動 orchestrator（Windows）

```powershell
cd G:\AI_WORK_512\repos\linear-orchestrator
powershell -ExecutionPolicy Bypass -File .\scripts\Start-LinearOrchestrator.ps1 -Wait
powershell -ExecutionPolicy Bypass -File .\scripts\Check-LinearOrchestrator.ps1 -Public
```

## 驗證

```powershell
# 本機
Invoke-WebRequest http://127.0.0.1:8645/healthz -UseBasicParsing

# 公網
Invoke-WebRequest https://webhook.whoasked.vip/healthz -UseBasicParsing
```

簽章測試 webhook 見 `G:\AI_WORK_512\repos\cloudflared\HERMES-WEBHOOK.md`。

## 為什麼不能本地改 token tunnel

Cloudflare token tunnel 的 ingress 只在 Dashboard 改。本地 YAML（舊 home-tunnel）已 DEPRECATED。
