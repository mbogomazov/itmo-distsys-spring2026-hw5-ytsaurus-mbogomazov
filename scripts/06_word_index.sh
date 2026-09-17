#!/usr/bin/env bash
# Own MapReduce job: search index (word, [line numbers]) built from //home/mbogomazov/sonnets
# (the input table is created and filled by scripts/04_word_count.sh).
#
#   //home/mbogomazov/sonnets (lineno, text)
#       --map-reduce mapreduce/word_index.py-->  //home/mbogomazov/word_index (word, lines: List<Int64>)
set -euo pipefail
cd "$(dirname "$0")/.."
source deploy/env.sh

INPUT=//home/mbogomazov/sonnets
RESULT=//home/mbogomazov/word_index

set -x
# 0. local test of the same code (sort = shuffle), just to show what the job produces
python3 mapreduce/word_index.py map < data/sonnets.tsv | LC_ALL=C sort -t$'\t' -k1,1 \
    | python3 mapreduce/word_index.py reduce > artifacts/word_index_local.jsonl
grep -E '"word": "(fairest|increase)"' artifacts/word_index_local.jsonl

# 1. result table: `lines` is a typed list (type_v3 = List<Int64>)
yt create table "$RESULT" --force --attributes '{schema = [
    {name = word;  type = string};
    {name = lines; type_v3 = {type_name = list; item = int64}}
]}'

# 2. run MapReduce. Map talks dsv, reduce reads dsv and writes json (json supports lists).
yt map-reduce \
    --mapper  "python3 word_index.py map" \
    --reducer "python3 word_index.py reduce" \
    --map-local-file    mapreduce/word_index.py \
    --reduce-local-file mapreduce/word_index.py \
    --src "$INPUT" \
    --dst "$RESULT" \
    --reduce-by word \
    --map-input-format dsv --map-output-format dsv \
    --reduce-input-format dsv --reduce-output-format json

# 3. look at the result
yt get "$RESULT/@row_count"
yt read-table "$RESULT[:#10]" --format json
