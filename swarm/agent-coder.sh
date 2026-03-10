#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
AGENT="coder"
LAST_SEEN_ID=0

log $AGENT "Starting coder agent"

while true; do
    log $AGENT "Checking for tasks..."

    tasks_output=$(ah_as $AGENT read tasks --limit 10 2>/dev/null || echo "")

    # Find the latest unclaimed TASK
    task_line=$(echo "$tasks_output" | grep "TASK:" | tail -1 || true)

    if [ -z "$task_line" ]; then
        log $AGENT "No tasks found. Sleeping..."
        sleep "$POLL_INTERVAL"
        continue
    fi

    # Extract post ID: format is [ID] agent (timestamp): TASK: ...
    post_id=$(echo "$task_line" | sed -n 's/^\[\([0-9]*\)\].*/\1/p')
    task_content=$(echo "$task_line" | sed 's/^[^T]*TASK: //')

    # Skip already-processed tasks
    if [ -n "$post_id" ] && [ "$post_id" -le "$LAST_SEEN_ID" ] 2>/dev/null; then
        sleep "$POLL_INTERVAL"
        continue
    fi

    log $AGENT "Claiming task #$post_id: ${task_content:0:100}..."
    ah_as $AGENT reply "$post_id" "CLAIMED by swarm-coder. Working on it." || true
    LAST_SEEN_ID="$post_id"

    # Create a working branch
    cd "$REPO_DIR"
    branch="swarm/task-$post_id"
    git checkout -b "$branch" dev 2>/dev/null || git checkout "$branch" 2>/dev/null || true

    # Use Claude Code to implement
    log $AGENT "Invoking Claude Code to implement..."
    result=$(cd "$REPO_DIR" && ask_claude "
You are a coder agent for the agenthub project (a Go server + CLI for AI agent collaboration).
Implement this task:

$task_content

Rules:
- Make minimal, focused changes
- Only modify files directly related to the task
- Do NOT modify the justfile, swarm/ directory, or README
- If adding tests, follow existing Go test patterns
- After making changes, output a brief summary (1-3 sentences) of what you changed
" "Read,Glob,Grep,Edit,Write,Bash")

    # Commit and push
    git add -A
    if git diff --cached --quiet; then
        log $AGENT "No changes made. Posting skip."
        ah_as $AGENT post results "SKIP task #$post_id -- no changes produced" || true
    else
        git commit -m "$(cat <<EOF
swarm-coder: task #$post_id

$task_content
EOF
)"
        ah_as $AGENT push || true
        commit_hash=$(git rev-parse --short HEAD)

        log $AGENT "Pushed $commit_hash. Posting result."
        ah_as $AGENT post results "DONE task #$post_id commit:$commit_hash -- ${result:0:500}" || true
    fi

    git checkout dev 2>/dev/null || true

    sleep "$POLL_INTERVAL"
done
