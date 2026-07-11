# CLAUDE.md

The canonical agent & contributor guidelines for this repository
live in **AGENTS.md** (the single source of truth, shared across
tools) — read it before modifying any code.

To cut per-session context, Claude Code loads a caveman-compressed
brief generated from AGENTS.md, not the full file. The brief is a
derived artifact: regenerate it with
`./scripts/build-agent-brief.sh` after editing AGENTS.md
(`scripts/lint.sh` prints a warning — never blocks — if it goes
stale), and never hand-edit it. Read AGENTS.md itself for the
authoritative, uncompressed text.

@.claude/AGENTS.brief.md
