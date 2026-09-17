#!/usr/bin/env bash
# Word Count from the official tutorial https://ytsaurus.tech/docs/ru/overview/try-yt#mr
# Only paths are changed: our text (Shakespeare's Sonnets) and tables inside //home/mbogomazov.
#
#   data/sonnets.tsv (lineno, text) --write-table--> //home/mbogomazov/sonnets
#   map-reduce with mapreduce/word-count.py        --> //home/mbogomazov/word_count (word, count)
set -euo pipefail
cd "$(dirname "$0")/.."
source deploy/env.sh

INPUT=//home/mbogomazov/sonnets
RESULT=//home/mbogomazov/word_count

set -x
# 0. text -> dsv "lineno=N<TAB>text=..." (line numbers are assigned HERE, before MapReduce:
#    map jobs process chunks in parallel and cannot know the global line number)
python3 data/prepare_text.py

# 1. input and output tables (static tables; columns are strings as in the tutorial).
#    --force recreates the table, so the script can be re-run from scratch.
yt create table "$INPUT" --force \
    --attributes '{schema = [{name = lineno; type = string}; {name = text; type = string}]}'
yt create table "$RESULT" --force \
    --attributes '{schema = [{name = count; type = string}; {name = word; type = string}]}'

# 2. upload the text
yt write-table "$INPUT" --format dsv < data/sonnets.tsv
yt read-table "$INPUT[:#10]" --format dsv

# 3. run MapReduce: the script file is uploaded to the cluster and executed by jobs
#    (map on every chunk -> shuffle/sort by `word` -> reduce on every group)
yt map-reduce \
    --mapper "python3 word-count.py map" \
    --reducer "python3 word-count.py reduce" \
    --map-local-file mapreduce/word-count.py \
    --reduce-local-file mapreduce/word-count.py \
    --src "$INPUT" \
    --dst "$RESULT" \
    --reduce-by word \
    --format dsv

# 4. top words: see scripts/run_yql.sh yql/top_words.yql
