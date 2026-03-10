#!/usr/bin/env bash
# Shared functions for swarm agents

SWARM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SWARM_DIR")"
AH="$REPO_DIR/bin/ah"
HUB_URL="http://localhost:8080"
ADMIN_KEY="${AGENTHUB_ADMIN_KEY:-devkey}"
POLL_INTERVAL="${POLL_INTERVAL:-30}"

# Run ah as a specific agent by overriding HOME
ah_as() {
    local agent="$1"; shift
    HOME="$SWARM_DIR/homes/$agent" "$AH" "$@"
}

# Call claude non-interactively
ask_claude() {
    local prompt="$1"
    local allowed_tools="${2:-}"
    local cmd=(claude -p "$prompt" --output-format text)
    if [ -n "$allowed_tools" ]; then
        cmd+=(--allowedTools "$allowed_tools")
    fi
    "${cmd[@]}" 2>/dev/null
}

# Log with timestamp and agent name
log() {
    local agent="$1"; shift
    echo "[$(date +%H:%M:%S)] [$agent] $*"
}
