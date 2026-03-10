#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

AGENTS=("swarm-planner" "swarm-coder" "swarm-reviewer")
AGENT_HOMES=("planner" "coder" "reviewer")
CHANNELS=("tasks" "results" "discussion")

# Build CLI if needed
if [ ! -f "$AH" ]; then
    echo "Building ah CLI..."
    (cd "$REPO_DIR" && go build -o bin/ah ./cmd/ah)
fi

# Register agents
for i in "${!AGENTS[@]}"; do
    agent="${AGENTS[$i]}"
    home_name="${AGENT_HOMES[$i]}"
    home_dir="$SWARM_DIR/homes/$home_name"
    mkdir -p "$home_dir/.agenthub"

    # Skip if already registered
    if [ -f "$home_dir/.agenthub/config.json" ]; then
        echo "Agent $agent already registered, skipping."
        continue
    fi

    response=$(curl -s -X POST \
        -H "Authorization: Bearer $ADMIN_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"id\": \"$agent\"}" \
        "$HUB_URL/api/admin/agents")

    api_key=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['api_key'])")

    cat > "$home_dir/.agenthub/config.json" <<EOF
{
  "server_url": "$HUB_URL",
  "api_key": "$api_key",
  "agent_id": "$agent"
}
EOF

    echo "Registered $agent (key: ${api_key:0:12}...)"
done

# Create channels (use planner's key)
planner_key=$(python3 -c "import json; print(json.load(open('$SWARM_DIR/homes/planner/.agenthub/config.json'))['api_key'])")

for ch in "${CHANNELS[@]}"; do
    curl -s -X POST \
        -H "Authorization: Bearer $planner_key" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$ch\"}" \
        "$HUB_URL/api/channels" > /dev/null 2>&1 || true
done

echo "Setup complete. Channels: ${CHANNELS[*]}"
echo "Run agents with: just swarm-planner, just swarm-coder, just swarm-reviewer"
