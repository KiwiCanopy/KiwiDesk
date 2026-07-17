#!/bin/bash
# Regenerates .claude/AGENTS.brief.md — a caveman-compressed copy of
# AGENTS.md that CLAUDE.md loads instead of the full file, to cut the
# per-session context Claude Code ingests. AGENTS.md stays the
# canonical, human-readable source; the brief is a DERIVED artifact and
# must never be hand-edited (scripts/check-agent-brief.sh enforces it).
#
# Requires the caveman skill (see AGENTS.md §4) plus either
# ANTHROPIC_API_KEY or a signed-in `claude` CLI — compression is an LLM
# pass, so output is not byte-reproducible. The freshness guard pins
# the SOURCE hash, not the compressed text, so any faithful run passes.
#
# NOTE: the compression pass is a full-document LLM call and commonly
# takes SEVERAL MINUTES. Run it without a short timeout (or in the
# background) — a 2-minute cap will kill it mid-pass and leave the
# brief stale. A stale brief only warns (never blocks), so it is safe
# to defer, but do not mistake "slow" for "hung".
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

[ -f "$SRC" ] || { echo "ERROR: $SRC missing" >&2; exit 1; }

# Locate the caveman-compress skill across known install roots.
CAVE=""
for base in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" "$HOME/.claude"; do
    cand="$base/plugins/marketplaces/caveman/skills/caveman-compress"
    if [ -d "$cand" ]; then CAVE="$cand"; break; fi
done
if [ -z "$CAVE" ]; then
    echo "ERROR: caveman-compress not found. Install caveman first" >&2
    echo "  (see AGENTS.md §4)." >&2
    exit 1
fi

sha="$(sha256 "$SRC")"

# Compress a scratch copy — caveman rewrites in place and drops a
# .original.md backup, so keep AGENTS.md itself untouched.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp "$SRC" "$tmp/AGENTS.md"
( cd "$CAVE" && python3 -m scripts "$tmp/AGENTS.md" )

mkdir -p "$(dirname "$OUT")"
{
    echo "<!-- GENERATED from AGENTS.md by scripts/build-agent-brief.sh"
    echo "     DO NOT EDIT. Regenerate after editing AGENTS.md."
    echo "     source-sha256: $sha -->"
    echo
    cat "$tmp/AGENTS.md"
} >"$OUT"

echo "Wrote $OUT (source-sha256 $sha)"
