#!/bin/bash
# Regenerate the Codex agent mirror from the committed Claude Code
# agents. `.claude/agents/*.md` is the source of truth — Claude Code
# reads it directly, and `.codex/agents/*.toml` is a generated copy
# that stays gitignored. Run this after editing any agent so the two
# cannot drift (.claude/rules/subagents.md).
#
# The mirror carries name, description and the instruction body. It
# does NOT carry `tools:` — the Codex agent format has no equivalent
# field, so a tool restriction expressed in frontmatter cannot
# survive the crossing. That is why the read-only reviewers also say
# so in their prose, which does survive; subagents.md records the
# limit.
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

# Emit the TOML form of one agent on stdout. `expected` is the
# basename Claude Code would route under if it routed on filenames;
# it does not — it routes on the frontmatter `name:` — so the two
# disagreeing would ship a roster whose entries answer to a name
# nobody calls. Fail instead.
#
# Exit codes: 3 malformed frontmatter, 4 name/filename mismatch,
# 5 a body that cannot be expressed as a TOML literal string.
render_toml() {
    local source_path="$1" expected="$2"

    # `tq` carries the TOML literal-string delimiter in as data:
    # macOS awk does not honour \x hex escapes, and three quotes
    # cannot be written inside a single-quoted awk program.
    awk -v expected="$expected" -v tq="'''" '
        # Undo YAML double-quote escaping in one left-to-right pass.
        # Two gsubs cannot do this: unescaping \\ first turns
        # \\" into \" and the second pass then eats a quote that was
        # meant to stay literal.
        function unquote(s,   out, i, c, n) {
            n = length(s)
            out = ""
            for (i = 1; i <= n; i++) {
                c = substr(s, i, 1)
                if (c == "\\" && i < n) {
                    i++
                    out = out substr(s, i, 1)
                } else {
                    out = out c
                }
            }
            return out
        }
        # TOML basic strings take backslash escapes, so a quote or a
        # backslash left raw would end the value early or invent an
        # escape sequence.
        function escape(s) {
            gsub(/\\/, "\\\\", s)
            gsub(/"/, "\\\"", s)
            return s
        }
        # A scalar this script can carry: one line, plain or double
        # quoted. A folded (>) or literal (|) block would silently
        # become its own sigil, and a wrapped continuation line would
        # be dropped — either way the routing key ships truncated.
        function scalar(value, key,   quoted) {
            if (value ~ /^[>|]/) {
                printf "%s: folded/literal scalars unsupported\n",
                    key > "/dev/stderr"
                exit 3
            }
            quoted = (value ~ /^".*"$/)
            sub(/^"/, "", value)
            sub(/"$/, "", value)
            return quoted ? unquote(value) : value
        }
        BEGIN { fence = 0 }
        /^---[[:space:]]*$/ && fence < 2 { fence++; next }
        fence == 1 {
            if ($0 ~ /^[A-Za-z_][A-Za-z0-9_-]*:/) {
                key = $0
                sub(/:.*$/, "", key)
                value = $0
                sub(/^[^:]*:[[:space:]]*/, "", value)
                if (key == "name") name = scalar(value, "name")
                if (key == "description") {
                    description = scalar(value, "description")
                }
                last = key
                next
            }
            # Anything else inside the frontmatter that is not blank
            # is a continuation of the previous key. Truncating it is
            # what makes this failure silent, so refuse.
            if ($0 ~ /[^[:space:]]/) {
                printf "%s: wrapped value unsupported\n",
                    last > "/dev/stderr"
                exit 3
            }
            next
        }
        fence == 2 { body = body $0 "\n" }
        END {
            if (name == "" || description == "") {
                print "missing name or description" > "/dev/stderr"
                exit 3
            }
            if (name != expected) {
                printf "frontmatter name %s != filename %s\n",
                    name, expected > "/dev/stderr"
                exit 4
            }
            # The body is emitted as a TOML *literal* multi-line
            # string so a backslash in an agent — a regex, a Swift
            # interpolation — stays the character it was. The one
            # sequence a literal string cannot hold is its own
            # delimiter.
            if (index(body, tq) > 0) {
                print "body contains a TOML literal delimiter" \
                    > "/dev/stderr"
                exit 5
            }
            sub(/^\n+/, "", body)
            sub(/\n+$/, "", body)
            printf "name = \"%s\"\n", escape(name)
            printf "description = \"%s\"\n", escape(description)
            printf "developer_instructions = %s\n%s%s\n",
                tq, body "\n", tq
        }
    ' "$source_path"
}

generate_into() {
    local target_dir="$1"
    local source_path name rendered status

    shopt -s nullglob
    local sources=("$SOURCE_DIR"/*.md)
    shopt -u nullglob
    if [[ "${#sources[@]}" -eq 0 ]]; then
        echo "ERROR: no agents in $SOURCE_DIR." >&2
        return 1
    fi

    mkdir -p "$target_dir"
    for source_path in "${sources[@]}"; do
        name="$(basename "$source_path" .md)"
        # Render to a temp file and move it into place only on
        # success. Redirecting straight at the target truncates it
        # before awk runs, so a failure leaves a 0-byte agent behind
        # that Codex would load as an empty definition.
        rendered="$(mktemp "$target_dir/.$name.XXXXXX")"
        status=0
        render_toml "$source_path" "$name" > "$rendered" || status=$?
        if [[ "$status" -ne 0 ]]; then
            rm -f "$rendered"
            echo "ERROR: $source_path (exit $status)." >&2
            return 1
        fi
        mv "$rendered" "$target_dir/$name.toml"
    done
}

sync() {
    local staging
    staging="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$staging'" EXIT

    # Build the whole mirror before replacing anything, so a failure
    # partway leaves the previous mirror intact rather than a
    # half-written roster.
    generate_into "$staging"
    rm -rf "$CODEX_DIR"
    mkdir -p "$(dirname "$CODEX_DIR")"
    mv "$staging" "$CODEX_DIR"
    trap - EXIT
    echo "Synced $(find "$CODEX_DIR" -name '*.toml' | wc -l | tr -d ' ')" \
        "Codex agents from .claude/agents/."
}

check() {
    local staging status
    staging="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$staging'" EXIT

    generate_into "$staging"
    if diff -r -q "$staging" "$CODEX_DIR" >/dev/null 2>&1; then
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
