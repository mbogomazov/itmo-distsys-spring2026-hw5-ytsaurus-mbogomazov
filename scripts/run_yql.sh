#!/usr/bin/env bash
# Run a YQL query from a file through Query Tracker and print the result rows as JSON lines.
# Usage: scripts/run_yql.sh yql/top_words.yql
# (The same query can be pasted into the web UI: http://localhost:18001 -> Queries)
set -euo pipefail
cd "$(dirname "$0")/.."
source deploy/env.sh

QUERY_FILE=$1
echo "===== $QUERY_FILE ====="
cat "$QUERY_FILE"
echo "===== result ====="
yt query yql "$(cat "$QUERY_FILE")" --format json
