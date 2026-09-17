#!/usr/bin/env bash
# 3) Read a row by its FULL composite key (author, title) - point lookup in the dynamic table.
#    Usage: scripts/03_select_by_key.sh ["author"] ["title"]
set -euo pipefail
source "$(dirname "$0")/../deploy/env.sh"

TABLE=//home/mbogomazov/books
AUTHOR=${1:-William Shakespeare}
TITLE=${2:-Sonnets}

set -x
# a) lookup-rows: we pass only key columns, get the whole row back
echo "{\"author\": \"$AUTHOR\", \"title\": \"$TITLE\"}" \
    | yt lookup-rows "$TABLE" --format json

# b) the same with a query language of dynamic tables (select-rows)
yt select-rows "* from [$TABLE] where author = \"$AUTHOR\" and title = \"$TITLE\"" --format json
