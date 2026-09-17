#!/usr/bin/env bash
# 2) Insert (upsert) rows into the dynamic table. Row = JSON object, one per line.
#    If a row with the same key (author, title) already exists it is overwritten.
set -euo pipefail
source "$(dirname "$0")/../deploy/env.sh"

TABLE=//home/mbogomazov/books

set -x
echo '{"author": "William Shakespeare", "title": "Sonnets", "year": 1609, "pages": 154}
{"author": "William Shakespeare", "title": "Hamlet", "year": 1603, "pages": 200}
{"author": "Lewis Carroll", "title": "Alice in Wonderland", "year": 1865, "pages": 96}' \
    | yt insert-rows "$TABLE" --format json

# show the whole (tiny) table: rows are stored sorted by the key (author, title)
yt select-rows "* from [$TABLE]" --format json
