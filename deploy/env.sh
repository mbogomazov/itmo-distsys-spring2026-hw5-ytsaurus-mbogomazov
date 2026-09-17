# Environment for the `yt` CLI (from pip package ytsaurus-client).
# Usage (from the repository root):  source deploy/env.sh
#
# Same variables as in the tutorial (https://ytsaurus.tech/docs/ru/overview/try-yt), Docker variant,
# but with port 18000 (see deploy/start.sh).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"

# virtualenv with `pip install ytsaurus-client` (created by deploy/install_cli.sh)
export PATH="$REPO_ROOT/.venv/bin:$PATH"

export YT_PROXY=localhost:18000
# disable automatic proxy discovery (as in the tutorial)
export YT_CONFIG_PATCHES='{proxy={enable_proxy_discovery=%false}}'
# local cluster without authentication, token is ignored but CLI wants something
export YT_TOKEN=password
