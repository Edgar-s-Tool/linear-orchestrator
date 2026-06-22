#!/usr/bin/env bash
# Install linear-orchestrator into WSL.
# Idempotent.
set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE"

VENV="$HOME/linear-orchestrator-venv"
echo "[1/4] create venv at $VENV (Linux-native FS, faster than /mnt/g)"
python3 -m venv "$VENV"

echo "[2/4] install package + deps"
"$VENV/bin/pip" install --upgrade pip >/dev/null
"$VENV/bin/pip" install -e "$HERE" >/dev/null

echo "[3/4] sanity import"
"$VENV/bin/python" -c "from linear_orchestrator.server import make_app; print('import ok')"

echo "[4/4] systemd unit"
if command -v systemctl >/dev/null 2>&1 && [ -d /etc/systemd/system ]; then
  SVC=/etc/systemd/system/linear-orchestrator.service
  sed "s|__HERE__|$HERE|g; s|__USER__|$(whoami)|g" "$HERE/systemd/linear-orchestrator.service.tmpl" | sudo tee "$SVC" >/dev/null
  sudo systemctl daemon-reload
  sudo systemctl enable linear-orchestrator >/dev/null 2>&1 || true
  echo "  systemd unit installed: $SVC"
  echo "  start with: sudo systemctl start linear-orchestrator"
else
  echo "  (systemd not present — use scripts/start.sh for nohup mode)"
fi

echo "DONE."
