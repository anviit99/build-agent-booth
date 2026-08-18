#!/usr/bin/env bash
# Booth HDMI + X Acquire + autodelete (macOS), self-contained folder.
# Forces AGENT_MODE=booth after sourcing .env.agent.
#
# Usage: ./run-agent.sh
#        ./run-agent.sh --env-file /path/to/.env.agent

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
IN_SETUP_KIT=0
if [[ "$(basename "$PARENT_DIR")" == "setup" ]]; then
  IN_SETUP_KIT=1
  REPO_ROOT="$(dirname "$PARENT_DIR")"
else
  REPO_ROOT=""
fi

find_backend() {
  local probe="$SCRIPT_DIR"
  local i candidate
  for i in 1 2 3 4 5 6; do
    for candidate in "harrords-backend" "selfbooth-backend"; do
      if [[ -n "$REPO_ROOT" && -d "$REPO_ROOT/$candidate/cmd/agent" ]]; then
        echo "$REPO_ROOT/$candidate"
        return 0
      fi
      if [[ -d "$probe/$candidate/cmd/agent" ]]; then
        echo "$probe/$candidate"
        return 0
      fi
    done
    probe="$(dirname "$probe")"
  done
  return 1
}

ENV_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file) ENV_FILE="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if [[ -z "$ENV_FILE" ]]; then
  for cand in "$SCRIPT_DIR/.env.agent" "$SCRIPT_DIR/env.agent" "$SCRIPT_DIR/env"; do
    if [[ -f "$cand" ]]; then
      ENV_FILE="$cand"
      break
    fi
  done
fi

if [[ -z "$ENV_FILE" || ! -f "$ENV_FILE" ]]; then
  echo "Missing .env.agent next to this script."
  echo "Copy .env.agent.example -> .env.agent (or Admin → Cài booth → tải .env.agent)."
  exit 1
fi

AGENT_BIN="$SCRIPT_DIR/selfbooth-agent"
# Pre-built zip may ship darwin-arm64 under alternate name
if [[ ! -f "$AGENT_BIN" && -f "$SCRIPT_DIR/selfbooth-agent-darwin-arm64" ]]; then
  cp "$SCRIPT_DIR/selfbooth-agent-darwin-arm64" "$AGENT_BIN"
  chmod +x "$AGENT_BIN"
fi

BACKEND="$(find_backend 2>/dev/null || true)"

if [[ ! -f "$AGENT_BIN" && -n "$BACKEND" && -f "$BACKEND/selfbooth-agent" ]]; then
  cp "$BACKEND/selfbooth-agent" "$AGENT_BIN"
  chmod +x "$AGENT_BIN"
  echo "Copied agent from backend/"
fi

if [[ ! -f "$AGENT_BIN" ]]; then
  if [[ "$IN_SETUP_KIT" -eq 1 && -n "$BACKEND" ]]; then
    echo "Building selfbooth-agent ..."
    (cd "$BACKEND" && go build -o "$AGENT_BIN" ./cmd/agent)
    chmod +x "$AGENT_BIN"
  else
    echo "Missing $AGENT_BIN — run ./build-agent.sh or copy binary here."
    exit 1
  fi
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a
export AGENT_MODE=booth

# Relative log path → this kit folder (not caller cwd).
if [[ -n "${AGENT_LOG_FILE:-}" && "$AGENT_LOG_FILE" != /* ]]; then
  export AGENT_LOG_FILE="$SCRIPT_DIR/$AGENT_LOG_FILE"
fi
if [[ -n "${AGENT_LOG_FILE:-}" ]]; then
  mkdir -p "$(dirname "$AGENT_LOG_FILE")"
fi

DELETE_KNOB="${AGENT_DELETE_AFTER_UPLOAD:-false}"
echo "Env:    $ENV_FILE"
echo "Bin:    $AGENT_BIN"
echo "Mode:   booth"
echo "Watch:  ${WATCH_DIR:-?}"
echo "Delete: AGENT_DELETE_AFTER_UPLOAD=$DELETE_KNOB"
[[ -n "${AGENT_LOG_FILE:-}" ]] && echo "Log:    $AGENT_LOG_FILE"
echo "=== Selfbooth Agent (HDMI + X Acquire + autodelete) ==="
exec "$AGENT_BIN" -env "$ENV_FILE"
