#!/usr/bin/env bash
# Non-systemd background start. PID written to .pid.
set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE"
LOG="$HERE/orchestrator.log"
PID="$HERE/.pid"
# Prefer ~/linear-orchestrator-venv (Linux-native FS = no /mnt/g pip slowness)
VENV="${VENV:-$HOME/linear-orchestrator-venv}"
[ -x "$VENV/bin/python" ] || VENV="$HERE/.venv"
PY="$VENV/bin/python"

if [ -f "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then
  echo "already running pid=$(cat "$PID")"
  exit 0
fi
setsid "$PY" -m linear_orchestrator </dev/null >>"$LOG" 2>&1 &
echo $! > "$PID"
sleep 1
if kill -0 "$(cat "$PID")" 2>/dev/null; then
  echo "started pid=$(cat "$PID") log=$LOG"
  ss -ltnp 2>/dev/null | grep 8645 || true
else
  echo "FAILED — see $LOG"
  tail -20 "$LOG"
  exit 1
fi
