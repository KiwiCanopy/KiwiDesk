#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Installation folders
CLAUDE_AGENTS_DIR="$ROOT_DIR/.claude/agents"
CODEX_AGENTS_DIR="$ROOT_DIR/.codex/agents"
WORKSPACE_SKILLS_DIR="$ROOT_DIR/.agents/skills"

# Committed KiwiDesk context appended to the generic reviewers so
# the tailoring survives every regeneration (see hybrid setup).
REVIEW_CONTEXT="$ROOT_DIR/scripts/kiwidesk-review-context.md"
TAILORED_AGENTS=("code-reviewer" "architect-reviewer")

# KiwiDesk-relevant subagents (category/agent-name)
AGENTS=(
    "01-core-development/frontend-developer"
    "01-core-development/ui-designer"
    "01-core-development/websocket-engineer"
    "02-language-specialists/swift-expert"
    "02-language-specialists/cpp-pro"
    "03-infrastructure/devops-engineer"
    "04-quality-security/code-reviewer"
    "04-quality-security/architect-reviewer"
    "04-quality-security/ui-ux-tester"
    "04-quality-security/accessibility-tester"
    "04-quality-security/performance-engineer"
    "06-developer-experience/git-workflow-manager"
    "06-developer-experience/documentation-engineer"
    "06-developer-experience/readme-generator"
    "07-specialized-domains/api-documenter"
    "07-specialized-domains/seo-specialist"
    "08-business-product/technical-writer"
    "09-meta-orchestration/codebase-orchestrator"
)

# Pin catalogs so generated agent behavior changes only after review.
CLAUDE_CATALOG_REV="947b44ca0c58d606b084e9cb1a2389335b49278b"
CODEX_CATALOG_REV="5605c9c18b3687993919d6cc467af4a34898fee2"
CLAUDE_RAW_URL="https://raw.githubusercontent.com/VoltAgent/"
CLAUDE_RAW_URL+="awesome-claude-code-subagents/$CLAUDE_CATALOG_REV/categories"
CODEX_RAW_URL="https://raw.githubusercontent.com/VoltAgent/"
CODEX_RAW_URL+="awesome-codex-subagents/$CODEX_CATALOG_REV/categories"

usage() {
    cat <<'EOF'
Usage: ./scripts/install-subagents.sh --claude | --codex

  --claude  Install Markdown agents for Claude Code and workspace skills.
  --codex   Install TOML agents for Codex.
EOF
}

tailor_claude_reviewers() {
    if [[ ! -f "$REVIEW_CONTEXT" ]]; then
        echo "WARN: $REVIEW_CONTEXT missing; reviewers left generic." >&2
        return
    fi

    for name in "${TAILORED_AGENTS[@]}"; do
        echo "Tailoring $name..."
        cat "$REVIEW_CONTEXT" >> "$CLAUDE_AGENTS_DIR/$name.md"
        cat "$REVIEW_CONTEXT" \
            >> "$WORKSPACE_SKILLS_DIR/$name/SKILL.md"
    done
}

tailor_codex_reviewer() {
    local name="$1"
    local agent_path="$CODEX_AGENTS_DIR/$name.toml"
    local temporary_path

    if [[ "$(tail -n 1 "$agent_path")" != '"""' ]]; then
        echo "ERROR: $agent_path has no closing instruction delimiter." >&2
        return 1
    fi

    temporary_path="$(mktemp "${agent_path}.XXXXXX")"
    {
        sed '$d' "$agent_path"
        printf '\n'
        cat "$REVIEW_CONTEXT"
        printf '"""\n'
    } > "$temporary_path"
    mv "$temporary_path" "$agent_path"
}

tailor_codex_reviewers() {
    if [[ ! -f "$REVIEW_CONTEXT" ]]; then
        echo "WARN: $REVIEW_CONTEXT missing; reviewers left generic." >&2
        return
    fi

    for name in "${TAILORED_AGENTS[@]}"; do
        echo "Tailoring $name..."
        tailor_codex_reviewer "$name"
    done
}

install_claude_agents() {
    echo "Creating Claude Code installation directories..."
    mkdir -p "$CLAUDE_AGENTS_DIR"

    for item in "${AGENTS[@]}"; do
        local category="${item%%/*}"
        local name="${item##*/}"

        echo "Installing $name for Claude Code..."
        curl -fsSL "$CLAUDE_RAW_URL/$category/$name.md" \
            -o "$CLAUDE_AGENTS_DIR/$name.md"

        mkdir -p "$WORKSPACE_SKILLS_DIR/$name"
        cp "$CLAUDE_AGENTS_DIR/$name.md" \
            "$WORKSPACE_SKILLS_DIR/$name/SKILL.md"
    done

    tailor_claude_reviewers
}

install_codex_agents() {
    echo "Creating Codex installation directory..."
    mkdir -p "$CODEX_AGENTS_DIR"

    for item in "${AGENTS[@]}"; do
        local category="${item%%/*}"
        local name="${item##*/}"

        echo "Installing $name for Codex..."
        curl -fsSL "$CODEX_RAW_URL/$category/$name.toml" \
            -o "$CODEX_AGENTS_DIR/$name.toml"
    done

    tailor_codex_reviewers
}

if [[ "$#" -ne 1 ]]; then
    usage >&2
    exit 64
fi

case "$1" in
    --claude)
        install_claude_agents
        echo "Installation complete! ${#AGENTS[@]} Claude Code agents active."
        ;;
    --codex)
        install_codex_agents
        echo "Installation complete! ${#AGENTS[@]} Codex agents active."
        ;;
    --help | -h)
        usage
        exit 0
        ;;
    *)
        echo "ERROR: unknown target '$1'." >&2
        usage >&2
        exit 64
        ;;
esac
