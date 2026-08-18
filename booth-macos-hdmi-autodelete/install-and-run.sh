#!/usr/bin/env bash
# One-shot: chmod, clear quarantine, run booth HDMI autodelete agent (macOS).
set -euo pipefail
cd "$(dirname "$0")"
chmod +x build-agent.sh run-agent.sh stop-agent-mac.sh install-and-run.sh 2>/dev/null || true
if command -v xattr >/dev/null 2>&1; then
  xattr -dr com.apple.quarantine . 2>/dev/null || true
fi
exec ./run-agent.sh "$@"
