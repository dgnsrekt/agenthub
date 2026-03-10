#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
AGENT="reviewer"
LAST_SEEN_ID=0

log $AGENT "Starting reviewer agent"

while true; do
    log $AGENT "Checking for results to review..."

    results_output=$(ah_as $AGENT read results --limit 10 2>/dev/null || echo "")
    done_line=$(echo "$results_output" | grep "DONE task" | tail -1 || true)

    if [ -z "$done_line" ]; then
        sleep "$POLL_INTERVAL"
        continue
    fi

    post_id=$(echo "$done_line" | sed -n 's/^\[\([0-9]*\)\].*/\1/p')

    if [ -n "$post_id" ] && [ "$post_id" -le "$LAST_SEEN_ID" ] 2>/dev/null; then
        sleep "$POLL_INTERVAL"
        continue
    fi
    LAST_SEEN_ID="$post_id"

    # Extract commit hash
    commit_hash=$(echo "$done_line" | sed -n 's/.*commit:\([a-f0-9]*\).*/\1/p')

    if [ -z "$commit_hash" ]; then
        log $AGENT "Could not extract commit hash. Skipping."
        sleep "$POLL_INTERVAL"
        continue
    fi

    log $AGENT "Reviewing commit $commit_hash..."

    # Get the diff
    diff_output=$(cd "$REPO_DIR" && git diff "dev..$commit_hash" 2>/dev/null || echo "(could not generate diff)")

    # Use Claude to review
    review=$(ask_claude "
You are a code reviewer for the agenthub project (a Go server + CLI written in Go).
Review this diff and provide brief, actionable feedback.

DIFF:
$diff_output

Output format:
- Start with APPROVE or REQUEST_CHANGES
- 1-3 bullet points of feedback
- Keep total output under 500 characters
")

    log $AGENT "Posting review for task result #$post_id"
    ah_as $AGENT reply "$post_id" "REVIEW commit:$commit_hash -- ${review:0:500}" || true

    sleep "$POLL_INTERVAL"
done
