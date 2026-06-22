#!/usr/bin/env bash
set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID="$HERE/.pid"
if [ -f "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then
  kill "$(cat "$PID")"
  rm -f "$PID"
  echo stopped
else
  pkill -f 'python -m linear_orchestrator' 2>/dev/null && echo "stopped (fallback)" || echo "not running"
fi
