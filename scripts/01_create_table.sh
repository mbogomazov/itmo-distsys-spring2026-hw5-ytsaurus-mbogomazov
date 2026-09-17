#!/usr/bin/env bash
# 1) Create directory //home/mbogomazov and a DYNAMIC table //home/mbogomazov/books
#    with a COMPOSITE primary key (author, title).
#
#    Dynamic table = table that supports point writes/reads by key (like a key-value DB).
#    Key columns are marked with sort_order=ascending; order of key columns matters:
#    rows are sorted first by author, then by title.
#    After creation the table must be MOUNTED (loaded into tablets) before reads/writes.
set -euo pipefail
source "$(dirname "$0")/../deploy/env.sh"

DIR=//home/mbogomazov
TABLE=$DIR/books

set -x
yt create map_node "$DIR" --ignore-existing   # directory in Cypress = map_node

yt create table "$TABLE" --attributes '{
    dynamic = %true;
    schema = [
        {name = author; type = utf8;   sort_order = ascending};
        {name = title;  type = utf8;   sort_order = ascending};
        {name = year;   type = uint32};
        {name = pages;  type = uint32}
    ]
}'

yt mount-table "$TABLE" --sync

yt get "$TABLE/@schema" --format json
yt get "$TABLE/@tablet_state"
