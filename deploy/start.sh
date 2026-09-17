#!/usr/bin/env bash
# Start a local single-node YTsaurus cluster in Docker on Apple M1 (amd64 images, Rosetta emulation).
#
# Source of truth: the OFFICIAL tutorial https://ytsaurus.tech/docs/ru/overview/try-yt (Docker variant),
# which runs yt/docker/local/run_local_cluster.sh (copy: deploy/run_local_cluster.sh).
# This file runs THE SAME two `docker run` commands as that script, with small changes that were needed
# on this laptop (M1 under emulation + other containers running):
#   * ports 18000/18001/18002 instead of 8000/8001/8002 (8000 is already busy);
#   * --platform linux/amd64 (there are no arm64 images, Docker Desktop runs them via Rosetta);
#   * --queue-agent-count 0 (queue agent is not needed for the homework; with it the start timed out
#     under emulation: "No healthy tablet cells in bundle default");
#   * no `--rm` and a 15 minute wait instead of 60 seconds: under emulation the start takes ~2-5 minutes,
#     the official script gives up after 60 s (the container keeps starting, but the UI is not launched);
#   * PERSISTENT DATA: the cluster working directory (YT_LOCAL_ROOT_PATH=/tmp, i.e. /tmp/locasaurus:
#     master changelogs/snapshots, table chunks, logs) lives in the named Docker volume $DATA_VOLUME.
#     `deploy/stop.sh` + `deploy/start.sh` keep all tables; even `docker rm` of the containers keeps them.
#     On restart `yt_local start` reuses the existing working directory, but its components assume a fresh cluster:
#     a stale bin/ytserver-query-tracker symlink (FileExistsError) and "already exists" errors for users/ACLs.
#     The entrypoint removes the symlink and runs yt_local via deploy/yt_local_restartable.py (see deploy/STOP.md).
#
# Usage:
#   ./deploy/start.sh   # first run: create containers; next runs: start the stopped containers again
#   ./deploy/stop.sh    # stop without losing data
#
# After start:
#   Web UI:              http://localhost:18001
#   HTTP proxy for `yt`: localhost:18000   (source deploy/env.sh)
# Stop / cleanup: see deploy/STOP.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROXY_PORT=18000
UI_PORT=18001
RPC_PORT=18002
CLUSTER=locasaurus
NETWORK=yt_local_cluster_network
DATA_VOLUME=ytsaurus-locasaurus-data
BACKEND_IMAGE=ghcr.io/ytsaurus/local:stable
UI_IMAGE=ghcr.io/ytsaurus/ui:stable

container_exists() { docker container inspect "$1" >/dev/null 2>&1; }

wait_backend_ready() {
    local since="$1"
    echo "Waiting for yt.backend (usually 2-5 minutes under emulation)..."
    for _ in $(seq 1 300); do
        if docker logs --since "$since" yt.backend 2>&1 | grep -q "Local YT started"; then
            echo "yt.backend is ready"
            return 0
        fi
        if [ "$(docker inspect -f '{{.State.Running}}' yt.backend)" != "true" ]; then
            echo "yt.backend exited. Last log lines:" >&2
            docker logs --since "$since" yt.backend 2>&1 | grep -v '^    ' | tail -30 >&2
            echo "See deploy/STOP.md (section 'если не стартует')." >&2
            exit 1
        fi
        sleep 3
    done
    echo "yt.backend is not ready after 15 minutes" >&2
    exit 1
}

started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- Fast path: containers already exist (stopped by deploy/stop.sh) -> just start them again ---
if container_exists yt.backend; then
    echo "Container yt.backend exists -> docker start (data is kept in volume $DATA_VOLUME)"
    docker start yt.backend >/dev/null
    wait_backend_ready "$started_at"
    if container_exists yt.frontend; then
        docker start yt.frontend >/dev/null
    fi
fi

# --- First run: create everything ---
if ! container_exists yt.backend; then
    # 0. Images (~7 GB backend + UI). Only amd64 builds exist.
    docker image inspect "$BACKEND_IMAGE" >/dev/null 2>&1 || docker pull --platform linux/amd64 "$BACKEND_IMAGE"
    docker image inspect "$UI_IMAGE" >/dev/null 2>&1 || docker pull --platform linux/amd64 "$UI_IMAGE"

    # 1. Docker network so that UI container can reach backend by name yt.backend
    docker network inspect "$NETWORK" >/dev/null 2>&1 || docker network create "$NETWORK"

    # 2. Named volume for the cluster working directory (created automatically if missing)
    docker volume create "$DATA_VOLUME" >/dev/null

    # 3. Backend: master, node (data + exec), scheduler, controller agent, HTTP proxy, query tracker, YQL agent.
    #    Entrypoint wrapper instead of the image's /usr/bin/start.sh (same `yt_local start` arguments):
    #      - remove leftovers of the previous run (stale symlink, pids of processes from the old container);
    #      - run yt_local via deploy/yt_local_restartable.py, which makes components' "create" idempotent.
    docker run -d --platform linux/amd64 \
        --name yt.backend --network "$NETWORK" \
        -p "$PROXY_PORT:80" -p "$RPC_PORT:$RPC_PORT" \
        -v "$DATA_VOLUME:/tmp" \
        -v "$SCRIPT_DIR/yt_local_restartable.py:/opt/yt_local_restartable.py:ro" \
        --env YT_FORCE_IPV4=1 --env YT_FORCE_IPV6=0 --env YT_USE_HOSTS=0 \
        --env YTSERVER_ALL_PATH=/usr/bin/ytserver-all --env YT_LOCAL_ROOT_PATH=/tmp \
        --entrypoint bash \
        "$BACKEND_IMAGE" \
        -c "rm -f /tmp/$CLUSTER/bin/ytserver-query-tracker /tmp/$CLUSTER/pids.txt && exec python3.8 /opt/yt_local_restartable.py start --proxy-port 80 --local-cypress-dir /var/lib/yt/local-cypress --ytserver-all-path /usr/bin/ytserver-all --sync \"\$@\"" yt-start \
        --fqdn localhost \
        --port-range-start 24400 --node-port-set-size 100 \
        --proxy-config "{coordinator={public_fqdn=\"localhost:$PROXY_PORT\"};}" \
        --rpc-proxy-count 0 --rpc-proxy-port "$RPC_PORT" \
        --node-count 1 \
        --queue-agent-count 0 \
        --address-resolver-config '{enable_ipv4=%true;enable_ipv6=%false;}' \
        --native-client-supported \
        --id "$CLUSTER" \
        -c '{name=query-tracker}' \
        -c '{name=yql-agent;config={path="/usr/bin";count=1;artifacts_path="/usr/bin"}}'

    wait_backend_ready "$started_at"
fi

# 4. Frontend (web UI) - stateless, created if missing
if ! container_exists yt.frontend; then
    docker run -d --platform linux/amd64 \
        --name yt.frontend --network "$NETWORK" \
        -p "$UI_PORT:80" \
        -e YT_LOCAL_CLUSTER_ID="$CLUSTER" \
        -e PROXY="localhost:$PROXY_PORT" \
        -e PROXY_INTERNAL=yt.backend:80 \
        -e APP_ENV=local \
        "$UI_IMAGE"
fi

echo
echo "Local cluster is up."
echo "  Web UI: http://localhost:$UI_PORT"
echo "  CLI:    source deploy/env.sh && yt list //home"
echo "  Stop without losing data: ./deploy/stop.sh"
