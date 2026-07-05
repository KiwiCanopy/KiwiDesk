#!/bin/bash
set -euo pipefail

# Installation folders
CLAUDE_AGENTS_DIR=".claude/agents"
GEMINI_SKILLS_DIR=".agents/skills"

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
    
    # 2. Re-publish as Workspace Skill for this IDE
    mkdir -p "$GEMINI_SKILLS_DIR/$NAME"
    cp "$CLAUDE_AGENTS_DIR/$NAME.md" "$GEMINI_SKILLS_DIR/$NAME/SKILL.md"
done

echo "Installation complete! All 6 subagents are active."
