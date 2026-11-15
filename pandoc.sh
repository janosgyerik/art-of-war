#!/usr/bin/env bash

set -euo pipefail

# Navigate to script directory
cd "$(dirname "$0")"

# --- PRE-FLIGHT DEPENDENCY CHECKS ---
MISSING_DEPS=0

if ! command -v pandoc &> /dev/null; then
    echo "Error: 'pandoc' is not installed or not in your PATH." >&2
    MISSING_DEPS=1
fi

if ! command -v wkhtmltopdf &> /dev/null; then
    echo "Error: 'wkhtmltopdf' is not installed or not in your PATH." >&2
    MISSING_DEPS=1
fi

if [ "$MISSING_DEPS" -eq 1 ]; then
    echo "Please install the missing dependencies and try again." >&2
    exit 1
fi
# ------------------------------------

basename="the-art-of-war"

pandoc_common_args=(
    -s
    --css=epub.css
    --toc
    --toc-depth=2
)

# Create a temporary file and ensure cleanup via trap
stripped_md=$(mktemp)
trap 'rm -f "$stripped_md"' EXIT

# Assumptions: We locate the TOC heading (e.g., "Table of Contents" or "Contents"),
# find the first h1 heading (# ) that appears after it, and strip everything before it.
toc_line=$(grep -n -E '^#+ .*(Table of Contents|Contents|TOC)' "$basename.md" | head -n 1 | cut -d: -f1)

if [ -n "${toc_line:-}" ]; then
    # Find the line number of the first h1 heading after the TOC heading
    first_chapter_line=$(tail -n +$((toc_line + 1)) "$basename.md" | grep -n -E '^# ' | head -n 1 | cut -d: -f1)

    if [ -n "${first_chapter_line:-}" ]; then
        actual_line=$((toc_line + first_chapter_line))
        # Keep everything from the first chapter onward
        tail -n +$actual_line "$basename.md" > "$stripped_md"
    else
        cp "$basename.md" "$stripped_md"
    fi
else
    cp "$basename.md" "$stripped_md"
fi

echo "Building EPUB for Kindle..."
pandoc metadata.yaml "$stripped_md" \
    -o "$basename".epub \
    --epub-cover-image=cover.jpeg \
    "${pandoc_common_args[@]}"

echo "Building PDF..."
pandoc metadata.yaml "$stripped_md" \
    -o "$basename".pdf \
    --pdf-engine=wkhtmltopdf \
    "${pandoc_common_args[@]}"
