#!/usr/bin/env bash
# Install YTsaurus CLI (`yt`) into a local virtualenv .venv (repository root).
# Tutorial: pip3 install --user ytsaurus-client  -- we use a venv instead to keep the system clean.
set -euo pipefail
cd "$(dirname "$0")/.."

python3 -m venv .venv
.venv/bin/pip install --upgrade ytsaurus-client
.venv/bin/yt --version
