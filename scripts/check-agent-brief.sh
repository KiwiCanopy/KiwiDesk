#!/bin/bash
# Freshness reminder for .claude/AGENTS.brief.md (the caveman-compressed
# AGENTS.md that CLAUDE.md loads). WARN-ONLY: never blocks a commit or
# CI — it only prints a reminder when the brief is missing or its
# recorded source-sha256 no longer matches AGENTS.md (i.e. AGENTS.md was
# edited without regenerating the brief). Run by scripts/lint.sh and the
# pre-commit hook. Regenerate with scripts/build-agent-brief.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/AGENTS.md"
OUT="$ROOT/.claude/AGENTS.brief.md"

sha256() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        sha256sum "$1" | awk '{print $1}'
    fi
}

if [ ! -f "$OUT" ]; then
    echo "WARNING: $OUT missing;" \
        "run scripts/build-agent-brief.sh" >&2
    exit 0
fi

want="$(sha256 "$SRC")"
have="$(grep -m1 'source-sha256:' "$OUT" | awk '{print $2}')"

if [ "$want" != "$have" ]; then
    echo "WARNING: .claude/AGENTS.brief.md is stale" \
        "(AGENTS.md changed since it was built)." >&2
    echo "  Regenerate: scripts/build-agent-brief.sh" >&2
    exit 0
fi

echo "agent-brief OK (source-sha256 $want)"
