#!/bin/bash
# Regenerate the Codex agent mirror from the committed Claude Code
# agents. `.claude/agents/*.md` is the source of truth — Claude Code
# reads it directly, and `.codex/agents/*.toml` is a generated copy
# that stays gitignored. Run this after editing any agent so the two
# cannot drift (.claude/rules/subagents.md).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/.claude/agents"
CODEX_DIR="$ROOT_DIR/.codex/agents"

usage() {
    cat <<'EOF'
Usage: ./scripts/sync-agents.sh [--check]

  (no flag)  Regenerate .codex/agents/*.toml from .claude/agents/*.md.
  --check    Verify the mirror is current; exit 1 if it is not. Local
             only — the mirror is gitignored, so CI has none to check.
EOF
}

# Emit the TOML form of one agent on stdout. The Markdown frontmatter
# carries `name:` and `description:`; everything after the closing
# `---` becomes the Codex instruction block.
render_toml() {
    local source_path="$1"

    awk '
        # The frontmatter value is a YAML double-quoted scalar, so
        # an embedded quote arrives escaped; undo that before
        # re-escaping for TOML, or the mirror gains a literal
        # backslash the Markdown never had.
        function unquote(s) {
            gsub(/\\"/, "\"", s)
            return s
        }
        # TOML basic strings take backslash escapes; a quote or a
        # backslash left raw would end the value early and produce a
        # file that parses as something else.
        function escape(s) {
            gsub(/\\/, "\\\\", s)
            gsub(/"/, "\\\"", s)
            return s
        }
        BEGIN { fence = 0 }
        /^---[[:space:]]*$/ && fence < 2 { fence++; next }
        fence == 1 {
            if ($0 ~ /^name:[[:space:]]/) {
                sub(/^name:[[:space:]]*/, "")
                gsub(/^"|"$/, "")
                name = escape(unquote($0))
            }
            if ($0 ~ /^description:[[:space:]]/) {
                sub(/^description:[[:space:]]*/, "")
                gsub(/^"|"$/, "")
                description = escape(unquote($0))
            }
            next
        }
        fence == 2 { body = body $0 "\n" }
        END {
            if (name == "" || description == "") {
                print "MISSING_FRONTMATTER" > "/dev/stderr"
                exit 3
            }
            # Trim leading and trailing blank lines from the body.
            sub(/^\n+/, "", body)
            sub(/\n+$/, "", body)
            printf "name = \"%s\"\n", name
            printf "description = \"%s\"\n", description
            printf "developer_instructions = \"\"\"\n%s\"\"\"\n", body "\n"
        }
    ' "$source_path"
}

generate_into() {
    local target_dir="$1"
    local source_path name

    mkdir -p "$target_dir"
    for source_path in "$SOURCE_DIR"/*.md; do
        name="$(basename "$source_path" .md)"
        if ! render_toml "$source_path" > "$target_dir/$name.toml"; then
            echo "ERROR: $source_path has no name/description." >&2
            return 1
        fi
    done
}

sync() {
    local count
    rm -rf "$CODEX_DIR"
    generate_into "$CODEX_DIR"
    count="$(find "$CODEX_DIR" -name '*.toml' | wc -l | tr -d ' ')"
    echo "Synced $count Codex agents from .claude/agents/."
}

check() {
    local temporary_dir status
    temporary_dir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$temporary_dir'" EXIT

    generate_into "$temporary_dir"
    if diff -r -q "$temporary_dir" "$CODEX_DIR" >/dev/null 2>&1; then
        echo "Codex agent mirror is current."
        status=0
    else
        echo "ERROR: .codex/agents/ is stale." >&2
        echo "Run ./scripts/sync-agents.sh" >&2
        status=1
    fi
    return "$status"
}

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "ERROR: $SOURCE_DIR not found." >&2
    exit 66
fi

case "${1-}" in
    "")
        sync
        ;;
    --check)
        check
        ;;
    --help | -h)
        usage
        exit 0
        ;;
    *)
        echo "ERROR: unknown option '$1'." >&2
        usage >&2
        exit 64
        ;;
esac
