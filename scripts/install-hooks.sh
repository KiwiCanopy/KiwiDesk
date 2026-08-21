#!/bin/bash
# Installs KiwiDesk git hooks (symlinks into .git/hooks).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$ROOT/.git/hooks"

if [ ! -d "$ROOT/.git" ]; then
    echo "ERROR: not a git repository: $ROOT"
    exit 1
fi

ln -sf "$ROOT/scripts/pre-commit" "$HOOKS_DIR/pre-commit"
chmod +x "$ROOT/scripts/pre-commit" "$ROOT/scripts/lint.sh" \
    "$ROOT/scripts/check-doc-anchors"
echo "Installed pre-commit hook -> scripts/pre-commit"
