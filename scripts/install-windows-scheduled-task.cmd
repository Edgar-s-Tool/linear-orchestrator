@echo off
REM Install a Windows Scheduled Task that auto-starts linear-orchestrator
REM natively on Windows (no WSL). Runs at user logon.

setlocal
set "TASK=linear-orchestrator-on-logon"
set "REPO=G:\AI_WORK_512\repos\linear-orchestrator"
set "TRIGGER=%REPO%\scripts\start-orchestrator-at-login.ps1"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "TR=%PS% -NoProfile -ExecutionPolicy Bypass -File \"%TRIGGER%\""

echo Removing old task if any...
schtasks /Delete /TN "%TASK%" /F >nul 2>&1

echo Creating scheduled task "%TASK%" (trigger: at logon, runs as current user)...
schtasks /Create /SC ONLOGON /TN "%TASK%" /TR "%TR%" /RL LIMITED /F
if errorlevel 1 (
  echo Failed to create task.
  pause
  exit /b 1
)

echo.
echo Done. Task fires on next Windows logon.
echo Run now:  schtasks /Run /TN "%TASK%"
echo Remove:    schtasks /Delete /TN "%TASK%" /F
echo Check:     powershell -ExecutionPolicy Bypass -File "%REPO%\scripts\Check-LinearOrchestrator.ps1"
endlocal
