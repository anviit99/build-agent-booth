#!/usr/bin/env bash
# Stop selfbooth-agent (macOS)
set -euo pipefail
if pkill -f './selfbooth-agent' 2>/dev/null || pkill -f 'selfbooth-agent' 2>/dev/null; then
  echo "Stopped selfbooth-agent."
else
  echo "No selfbooth-agent running."
fi
