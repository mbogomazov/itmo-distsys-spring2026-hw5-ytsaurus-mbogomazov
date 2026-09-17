#!/usr/bin/env python3
"""Download Shakespeare's Sonnets (Project Gutenberg #1041) and clean the text.

What the cleaning does (so line numbers are easy to check by eye):
  * keeps only the book itself (drops the Gutenberg header/footer);
  * CRLF -> LF, removes the BOM;
  * replaces typographic quotes with plain ASCII ones (’ -> ');
  * collapses runs of empty lines into a single empty line.

Result:
  data/sonnets.txt  - the text (1 line of the file = 1 row in YTsaurus)
  data/sonnets.tsv  - the same text in YTsaurus "dsv" format: lineno=N<TAB>text=...

Usage: python3 data/prepare_text.py   (does nothing if data/sonnets.txt and data/sonnets.tsv already exist)
"""

import urllib.request
from pathlib import Path

URL = "https://www.gutenberg.org/cache/epub/1041/pg1041.txt"
DATA_DIR = Path(__file__).resolve().parent

REPLACEMENTS = {"’": "'", "‘": "'", "“": '"', "”": '"', "—": "-", "™": "(TM)", "•": "*"}


def main() -> None:
    if (DATA_DIR / "sonnets.txt").exists() and (DATA_DIR / "sonnets.tsv").exists():
        # already prepared (files are in the repo) - no need to download again
        print(f"lines: {len((DATA_DIR / 'sonnets.txt').read_text(encoding='ascii').splitlines())} (cached)")
        return

    raw: str = urllib.request.urlopen(URL).read().decode("utf-8-sig")
    lines: list[str] = raw.replace("\r\n", "\n").split("\n")

    start: int = next(i for i, l in enumerate(lines) if l.startswith("*** START OF")) + 1
    end: int = next(i for i, l in enumerate(lines) if l.startswith("*** END OF"))
    body: list[str] = lines[start:end]

    cleaned: list[str] = []
    for line in body:
        for src, dst in REPLACEMENTS.items():
            line = line.replace(src, dst)
        line = line.rstrip()
        if line == "" and (not cleaned or cleaned[-1] == ""):
            continue  # collapse several empty lines into one
        cleaned.append(line)
    while cleaned and cleaned[-1] == "":
        cleaned.pop()

    (DATA_DIR / "sonnets.txt").write_text("\n".join(cleaned) + "\n", encoding="ascii")

    # dsv format for `yt write-table --format dsv` (same as awk command in the tutorial)
    with open(DATA_DIR / "sonnets.tsv", "w", encoding="ascii") as tsv:
        for lineno, line in enumerate(cleaned, start=1):
            tsv.write(f"lineno={lineno}\ttext={line}\n")

    print(f"lines: {len(cleaned)}")


if __name__ == "__main__":
    main()
