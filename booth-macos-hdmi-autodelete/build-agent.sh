#!/usr/bin/env bash
# Builds selfbooth-agent into THIS kit folder.
# Autodelete is runtime-only (AGENT_DELETE_AFTER_UPLOAD in .env.agent).
#
# Usage: ./build-agent.sh
#        ./build-agent.sh /path/to/harrords-backend

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="${1:-}"

find_backend() {
  local probe="$SCRIPT_DIR"
  local i candidate
  for i in 1 2 3 4 5 6; do
    for candidate in "harrords-backend" "selfbooth-backend"; do
      if [[ -d "$probe/$candidate/cmd/agent" ]]; then
        echo "$probe/$candidate"
        return 0
      fi
    done
    probe="$(dirname "$probe")"
  done
  return 1
}

if [[ -z "$BACKEND_DIR" ]]; then
  BACKEND_DIR="$(find_backend)" || true
fi

if [[ -z "$BACKEND_DIR" || ! -d "$BACKEND_DIR/cmd/agent" ]]; then
  echo "Cannot locate harrords-backend/cmd/agent (or selfbooth-backend)." >&2
  echo "Usage: ./build-agent.sh /path/to/harrords-backend" >&2
  exit 1
fi

if ! command -v go >/dev/null 2>&1; then
  echo "Go not found. Install Go 1.25+ or copy selfbooth-agent into this folder." >&2
  exit 1
fi

OUT="$SCRIPT_DIR/selfbooth-agent"
echo "Backend: $BACKEND_DIR"
echo "Output:  $OUT"

(
  cd "$BACKEND_DIR"
  echo "go test ./cmd/agent/ ..."
  go test ./cmd/agent/ -count=1
  echo "go build ./cmd/agent ..."
  go build -o "$OUT" ./cmd/agent
)

chmod +x "$OUT"
echo "Built: $OUT"
echo "Next: cp .env.agent.example .env.agent, edit WATCH_DIR / tokens, then ./run-agent.sh"
