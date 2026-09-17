#!/usr/bin/env python3
"""MapReduce job: inverted (search) index "word -> [line numbers]".

Based on the official word-count example from the YTsaurus tutorial
(yt/docs/code-examples/python/word-count.py, copy: mapreduce/word-count.py).
It is a *streaming* job: YTsaurus sends table rows to the script's stdin (one row per line)
and reads result rows from its stdout.

    map    : (lineno, text)          -> (word, lineno)  once per distinct word of the line
    shuffle: YTsaurus sorts and groups all map output by column `word`  (--reduce-by word)
    reduce : (word, lineno), ...     -> (word, lines)   lines = sorted unique list of line numbers

Formats (see scripts/06_word_index.sh):
    map input / map output / reduce input : dsv   "lineno=7<TAB>text=From fairest ..."
    reduce output                         : json  {"word": "from", "lines": [7, 117, 118]}
json is used for the reduce output because dsv has no lists, and the result column `lines`
is a real List<Int64> - so YQL can use ListHas(lines, 7).

Local check without a cluster (`sort` plays the role of shuffle):
    python3 mapreduce/word_index.py map < data/sonnets.tsv | LC_ALL=C sort -t$'\\t' -k1,1 \\
        | python3 mapreduce/word_index.py reduce | head
"""

import itertools
import json
import re
import sys
from typing import Dict, Iterable, Iterator, List, Union

DsvRow = Dict[str, str]
IndexRow = Dict[str, Union[str, List[int]]]

# a word = latin letters, optionally with inner apostrophes: "thy", "beauty's", "feed'st"
WORD_RE = re.compile(r"[a-z]+(?:'[a-z]+)*")


def normalize_words(text: str) -> List[str]:
    """Lowercase + drop punctuation: "Feed'st thy light's flame," -> ["feed'st", "thy", "light's", "flame"]."""
    return WORD_RE.findall(text.lower())


def decode_dsv(lines: Iterable[str]) -> Iterator[DsvRow]:
    """dsv line -> dict: "lineno=7<TAB>text=From fairest" -> {"lineno": "7", "text": "From fairest"}."""
    for line in lines:
        line = line.rstrip("\r\n")
        if not line:
            continue
        yield dict(field.split("=", 1) for field in line.split("\t"))


def do_map(rows: Iterable[DsvRow]) -> Iterator[str]:
    """For every DISTINCT word of the line emit (word, lineno) as a dsv line."""
    for row in rows:
        lineno = row["lineno"]
        for word in sorted(set(normalize_words(row.get("text", "")))):
            yield "word={}\tlineno={}".format(word, lineno)


def do_reduce(rows: Iterable[DsvRow]) -> Iterator[str]:
    """Input is sorted by `word`, so rows of one word are consecutive -> itertools.groupby."""
    for word, group in itertools.groupby(rows, key=lambda row: row["word"]):
        lines = sorted({int(row["lineno"]) for row in group})  # unique + ascending
        result: IndexRow = {"word": word, "lines": lines}
        yield json.dumps(result)


def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] not in ("map", "reduce"):
        sys.stderr.write("Usage: word_index.py map|reduce\n")
        sys.exit(1)

    rows = decode_dsv(sys.stdin)
    output = do_map(rows) if sys.argv[1] == "map" else do_reduce(rows)
    for line in output:
        sys.stdout.write(line + "\n")


if __name__ == "__main__":
    main()
