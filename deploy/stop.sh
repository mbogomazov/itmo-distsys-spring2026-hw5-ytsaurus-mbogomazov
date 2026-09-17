#!/usr/bin/env bash
# Stop the local YTsaurus cluster WITHOUT losing data.
# Containers are only stopped (not removed); cluster data lives in the Docker volume ytsaurus-locasaurus-data.
# Start again with ./deploy/start.sh - all tables in //home/mbogomazov are kept.
set -euo pipefail

for name in yt.frontend yt.backend; do
    if docker container inspect "$name" >/dev/null 2>&1; then
        # generous timeout: let yt_local shut its processes down cleanly
        docker stop --timeout 60 "$name"
    fi
done
echo "Stopped. Data is kept in Docker volume ytsaurus-locasaurus-data. Start again: ./deploy/start.sh"
