#!/usr/bin/env bash
# Stop all selfbooth-agent processes (prevents duplicate uploads)
# Usage: bash scripts/stop-agent-mac.sh

if pkill -f './selfbooth-agent' 2>/dev/null || pkill -f 'selfbooth-agent' 2>/dev/null; then
  echo "Stopped selfbooth-agent."
else
  echo "No selfbooth-agent running."
fi
