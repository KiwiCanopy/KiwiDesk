#!/bin/bash
set -euo pipefail

# Installation folders
CLAUDE_AGENTS_DIR=".claude/agents"
WORKSPACE_SKILLS_DIR=".agents/skills"

# Committed KiwiDesk context appended to the generic reviewers so
# the tailoring survives every regeneration (see hybrid setup).
REVIEW_CONTEXT="scripts/kiwidesk-review-context.md"
TAILORED_AGENTS=("code-reviewer" "architect-reviewer")

echo "Creating installation directories..."
mkdir -p "$CLAUDE_AGENTS_DIR"

# KiwiDesk-relevant subagents (category/agent-name)
AGENTS=(
    "01-core-development/ui-designer" 
    "01-core-development/websocket-engineer" 
    "02-language-specialists/swift-expert"
    "02-language-specialists/cpp-pro"
    "03-infrastructure/devops-engineer"
    "04-quality-security/code-reviewer"
    "04-quality-security/architect-reviewer"
    "06-developer-experience/git-workflow-manager"
    "09-meta-orchestration/codebase-orchestrator"
)

RAW_URL="https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories"

for item in "${AGENTS[@]}"; do
    CATEGORY="${item%%/*}"
    NAME="${item##*/}"
    
    echo "Installing $NAME..."
    
    # 1. Download Claude Code subagent
    curl -fsSL "$RAW_URL/$CATEGORY/$NAME.md" \
        -o "$CLAUDE_AGENTS_DIR/$NAME.md"
    
    # 2. Re-publish as a workspace skill for other tooling
    mkdir -p "$WORKSPACE_SKILLS_DIR/$NAME"
    cp "$CLAUDE_AGENTS_DIR/$NAME.md" \
        "$WORKSPACE_SKILLS_DIR/$NAME/SKILL.md"
done

# 3. Append KiwiDesk project context to the review subagents. The
#    generic body is regenerated above; this tail teaches them the
#    repo's actual rules (79-char lines, dlsym fallback, flat array,
#    etc.) instead of the generic coverage/complexity checklist.
if [[ -f "$REVIEW_CONTEXT" ]]; then
    for NAME in "${TAILORED_AGENTS[@]}"; do
        echo "Tailoring $NAME with KiwiDesk context..."
        cat "$REVIEW_CONTEXT" >> "$CLAUDE_AGENTS_DIR/$NAME.md"
        cat "$REVIEW_CONTEXT" \
            >> "$WORKSPACE_SKILLS_DIR/$NAME/SKILL.md"
    done
else
    echo "WARN: $REVIEW_CONTEXT missing; reviewers left generic." >&2
fi

echo "Installation complete! ${#AGENTS[@]} subagents are active."
