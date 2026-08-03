#!/usr/bin/env python3
"""Build the glide lexicon from Norvig's count_1w.txt (word<TAB>count, from the
Google Web Trillion Word Corpus; the data is free to use — norvig.com/ngrams).

Usage: python3 scripts/build_glide_lexicon.py count_1w.txt Shared/Resources/glide_lexicon.txt
"""
import re
import sys

TOP_N = 50_000
WORD = re.compile(r"^[a-z]{2,20}$")

# count_1w.txt strips apostrophes, so contractions are re-added by hand with
# counts on the same scale as the corpus (rough web frequencies).
CONTRACTIONS = {
    "it's": 500e6, "i'm": 300e6, "don't": 250e6, "that's": 200e6, "can't": 150e6,
    "you're": 140e6, "i've": 120e6, "he's": 110e6, "she's": 90e6, "i'll": 90e6,
    "won't": 80e6, "they're": 80e6, "there's": 80e6, "let's": 70e6, "what's": 70e6,
    "we're": 70e6, "didn't": 70e6, "i'd": 60e6, "doesn't": 60e6, "isn't": 60e6,
    "you'll": 50e6, "we'll": 50e6, "you've": 50e6, "wasn't": 40e6, "we've": 40e6,
    "he'll": 30e6, "she'll": 30e6, "who's": 30e6, "here's": 30e6, "aren't": 30e6,
    "they'll": 25e6, "they've": 25e6, "wouldn't": 25e6, "couldn't": 25e6,
    "shouldn't": 20e6, "haven't": 20e6, "hasn't": 20e6, "weren't": 15e6,
    "you'd": 15e6, "we'd": 12e6, "they'd": 10e6, "hadn't": 8e6,
}

def main(source: str, dest: str) -> None:
    rows: list[tuple[str, float]] = []
    with open(source) as handle:
        for line in handle:
            parts = line.split()
            if len(parts) != 2 or not WORD.match(parts[0]):
                continue
            rows.append((parts[0], float(parts[1])))
    rows.sort(key=lambda r: -r[1])
    rows = rows[:TOP_N] + list(CONTRACTIONS.items())
    rows.sort(key=lambda r: -r[1])
    with open(dest, "w") as out:
        for word, count in rows:
            out.write(f"{word}\t{int(count)}\n")
    print(f"wrote {len(rows)} words to {dest}")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
