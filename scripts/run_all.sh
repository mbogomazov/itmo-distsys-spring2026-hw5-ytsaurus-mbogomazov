#!/usr/bin/env bash
# Run the whole homework on a freshly started cluster (deploy/start.sh) and save outputs to artifacts/.
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/01_create_table.sh            > artifacts/01_create_table.txt 2>&1
bash scripts/02_insert_row.sh              > artifacts/02_insert_row.txt 2>&1
bash scripts/03_select_by_key.sh           > artifacts/03_select_by_key.txt 2>&1
bash scripts/04_word_count.sh              > artifacts/04_word_count.txt 2>&1
bash scripts/run_yql.sh yql/top_words.yql  > artifacts/05_top_words.txt 2>&1
bash scripts/06_word_index.sh              > artifacts/06_word_index.txt 2>&1
bash scripts/run_yql.sh yql/word_index_preview.yql > artifacts/06_word_index_preview.txt 2>&1
bash scripts/run_yql.sh yql/words_in_line.yql      > artifacts/07_words_in_line.txt 2>&1

tail -n 30 artifacts/05_top_words.txt
tail -n 6 artifacts/07_words_in_line.txt
