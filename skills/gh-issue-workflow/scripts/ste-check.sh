#!/usr/bin/env bash
# ste-check.sh <procedural|descriptive|mixed> <file>
# Runs the simplified-technical-english checker on a file. Exit 0 = clean.
set -u
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/lib.sh"
mode="${1:?mode}"; file="${2:?file}"
d=$(find_skill_dir simplified-technical-english) || { echo "simplified-technical-english skill not installed" >&2; exit 2; }
python3 -I "$d/scripts/ste_check.py" --mode "$mode" --word-list "$d/references/word-list.md" "$file"
