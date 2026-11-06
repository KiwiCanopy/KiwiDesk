#!/bin/bash
# KiwiDesk lint: formatting, line length (79), file size (350).
# Usage: scripts/lint.sh [--show-warnings] [file ...]
#        (defaults to all Swift files)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAX_LINE=79
SOFT_FILE=250
HARD_FILE=350
STATUS=0

# Soft-target warnings are advisory — the exit code decides
# (AGENTS.md §2.5) — and listing all ~150 of them per run drowned
# the errors, so the list is opt-in and the default is one count.
SHOW_WARNINGS=0
SOFT_COUNT=0
if [ "${1:-}" = "--show-warnings" ]; then
    SHOW_WARNINGS=1
    shift
fi

# A named directory is its Swift files, as the whole-tree walk reads.
# Only a named path scopes `swift format`, so a commit pays for what
# it staged (scripts/pre-commit).
FILES=()
FORMAT_ROOTS=("$ROOT/Sources" "$ROOT/Tests" "$ROOT/Package.swift")
if [ "$#" -gt 0 ]; then
    FORMAT_ROOTS=()
    for path in "$@"; do
        # A bare `a=b.swift` would read to awk as an assignment.
        case "$path" in
            /*) ;;
            *) path="./$path" ;;
        esac
        if [ -d "$path" ]; then
            FORMAT_ROOTS+=("$path")
            while IFS= read -r f; do
                [ -f "$f" ] && FILES+=("$f")
            done < <(find "$path" -name '*.swift')
        elif [ -f "$path" ]; then
            case "$path" in
                *.swift) FORMAT_ROOTS+=("$path") ;;
            esac
            FILES+=("$path")
        else
            # A typo would otherwise check nothing and read "Lint OK".
            echo "ERROR: no such file or directory: $path"
            STATUS=1
        fi
    done
else
    while IFS= read -r f; do
        [ -f "$f" ] && FILES+=("$f")
    done < <(find "$ROOT/Sources" "$ROOT/Tests" -name '*.swift' \
        2>/dev/null; echo "$ROOT/Package.swift")
fi

# Line length and file size, in one awk per argument batch rather than
# one per file, which cost most of a whole-tree run.
#
# .claude/rules/tests.md applies the §2.1 hard ceiling to suites as
# well, so a source file and a test file fail identically at the hard
# limit (#277, #560). The soft target stays source-only: dozens of test
# files exceed it. A genuine data-heavy fixture over the ceiling takes
# a named exemption here with its reason, never a blanket `*/Tests/*`
# skip, which once hid the whole backlog.
# shellcheck disable=SC2016
CHECK='
function finish() {
    if (file == "") return
    if (long > 0) {
        print "ERROR: lines exceed " max " chars in " file
        for (i = 1; i <= long && i <= 5; i++) print sample[i]
    }
    if (lines > hard) {
        print "ERROR: " file " has " lines " lines (hard limit " hard ")"
    } else if (file !~ /\/Tests\// && lines > soft) {
        print "#SOFT"
        if (show) {
            print "WARNING: " file " has " lines \
                " lines (sweet spot <=" soft ")"
        }
    }
}
FNR == 1 { finish(); file = FILENAME; long = 0 }
{ lines = FNR }
length($0) > max { long++; if (long <= 5) sample[long] = FNR ": " $0 }
END { finish() }
'
if [ "${#FILES[@]}" -gt 0 ]; then
    REPORT="$(printf '%s\0' "${FILES[@]}" | xargs -0 awk \
        -v max="$MAX_LINE" -v hard="$HARD_FILE" -v soft="$SOFT_FILE" \
        -v show="$SHOW_WARNINGS" "$CHECK")" || STATUS=1
    if [ -n "$REPORT" ]; then
        SOFT_COUNT="$(grep -c '^#SOFT$' <<<"$REPORT" || true)"
        grep -v '^#SOFT$' <<<"$REPORT" || true
        if grep -q '^ERROR:' <<<"$REPORT"; then
            STATUS=1
        fi
    fi
fi

if [ "$SOFT_COUNT" -gt 0 ] && [ "$SHOW_WARNINGS" -eq 0 ]; then
    echo "NOTE: $SOFT_COUNT file(s) over the $SOFT_FILE-line sweet" \
        "spot; rerun with --show-warnings to list them"
fi

# swift-format lint (ships with Xcode 16+ toolchains)
if [ "${#FORMAT_ROOTS[@]}" -eq 0 ]; then
    :
elif swift format --version >/dev/null 2>&1; then
    if ! swift format lint --strict --recursive --parallel \
        --configuration "$ROOT/.swift-format" \
        "${FORMAT_ROOTS[@]}"; then
        echo "ERROR: swift format lint failed"
        STATUS=1
    fi
else
    echo "NOTE: 'swift format' not found; skipping format lint"
fi

# Locale manifest freshness + drift guard (issue #9): fails if
# en.json doesn't match the L(...) call sites in Sources/KiwiDesk
# and Sources/KiwiDeskCore, or if the same key was authored with
# two different English strings.
if ! python3 "$ROOT/scripts/extract-keys" --check; then
    STATUS=1
fi

if [ "$STATUS" -eq 0 ]; then
    echo "Lint OK"
fi
exit $STATUS
