#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
AGENT="planner"

log $AGENT "Starting planner agent"

while true; do
    log $AGENT "Analyzing codebase for improvements..."

    existing_tasks=$(ah_as $AGENT read tasks --limit 10 2>/dev/null || echo "(no tasks yet)")

    task=$(cd "$REPO_DIR" && ask_claude "
You are a planner agent for the agenthub project (a Go server + CLI for AI agent collaboration).
The codebase is in the current directory.

Look at the codebase and identify ONE small, concrete improvement task.
Focus on: missing tests, error handling gaps, code quality, or small useful features.

DO NOT suggest tasks related to the swarm/ directory or justfile.

Existing tasks on the board (avoid duplicates):
$existing_tasks

Output ONLY a task description in 1-3 sentences. Be specific about which file(s) and what to do.
No preamble, no markdown formatting.
" "Read,Glob,Grep")

    if [ -n "$task" ]; then
        log $AGENT "Posting task: ${task:0:100}..."
        ah_as $AGENT post tasks "TASK: $task" || true
    else
        log $AGENT "No task generated this cycle."
    fi

    log $AGENT "Sleeping ${POLL_INTERVAL}s..."
    sleep "$POLL_INTERVAL"
done
