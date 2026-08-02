---
paths:
  - ".claude/agents/**"
  - "scripts/sync-agents.sh"
---

# Subagents

Canonical for the roster and for how an agent file is written
(AGENTS.md §4 and §5 index it). It loads when you edit an agent,
which is the moment it binds.

**When** to delegate is not here — that decision is made while
editing something else entirely, so this file would never be on
screen for it. AGENTS.md §4 keeps it.

## Why the roster is committed and hand-written

The roster used to be fetched per clone from a third-party catalog
and patched by appending a KiwiDesk context block. Both halves of
that failed, and both failures are the reason for the rules below.

The generic bodies invented gates the project had never adopted —
coverage percentages, complexity ceilings — so the appended block
spent its opening paragraph cancelling them. They addressed a
"context manager" agent that does not exist, declared MCP tools
that do not resolve here, and closed with a template delivery line
quoting an invented quality score. Sixteen of eighteen carried no
KiwiDesk context at all, and several described stacks this repo
does not contain.

The append was worse, because it worked by copying rules out of
their owning files. The copy baked into the generated
`code-reviewer` and the copy in the context block it was appended
from had already drifted apart on what a profile may own — two
live statements of one rule, disagreeing, both loading as
instructions.

An agent definition is repo policy. Keep it in git, next to the
rules it enforces, and write it by hand.

## The roster

The directory is the truth; this table is the index. When they
disagree, the row is what to fix. Adding an agent loads this file,
so keep the table current in the same change.

| Agent | Reach for it when |
|---|---|
| `code-reviewer` | A finished diff needs a line-level pass before a PR |
| `architect-reviewer` | The same diff needs a seam-level pass, in parallel |
| `guard-prover` | A change adds or edits a test, guard, canary or assertion |
| `swift-expert` | The hard part is the language — isolation, `Sendable`, view identity, AppKit interop |
| `ui-designer` | A Settings surface is being designed, or a proposed panel needs grading |
| `docs-steward` | Prose needs writing or auditing — `docs/`, a rule file, a §5 row |
| `localization-auditor` | User-facing strings changed, or new keys need translating |
| `site-engineer` | `site/` changed, or the shipped pages need auditing |

Each agent's `description` is canonical for what it does; the row
above is only the routing hint.

## Writing an agent file

- **Route, never restate.** An agent points at the owning
  `.claude/rules/*.md` and reads it; it does not carry a copy of
  the rule. A copy is a second live statement that drifts, which is
  exactly how the retired setup failed. `rule-authoring.md` binds
  agent files for the same reason it binds rule files: they load as
  instructions.
- **Derive, never pin.** Where a number or a set is unavoidable —
  a locale list, a language version, a platform floor — say which
  file to read it from. A pinned count is wrong on the commit that
  changes it, and nothing notices.
- **The `description` is the routing key.** It decides whether the
  agent is ever selected, so write it as *when to use this*, in the
  third person, naming concrete triggers. A description that
  describes the agent's expertise instead of its trigger will not
  route.
- **Give the fewest tools that let it finish.** A review agent gets
  no `Write` or `Edit` — the retired reviewers held both, which
  bought nothing and let a reviewer rewrite what it was judging.
- **Carry the calibration, not the checklist.** The highest-value
  section is *what not to flag*: the thresholds this project has
  not adopted, the sanctioned exceptions, the neighbouring agent's
  territory. A checklist of virtues is filler; a list of things the
  agent must stay quiet about is not.
- **State the non-goals and name who owns them.** Every agent ends
  a scope question by naming the agent that owns it, so a caller
  never has to guess and two agents never both answer.
- **One output contract.** Findings are `path:line — SEVERITY:
  problem. fix.`, most severe first, closing with a count line or
  `No findings.` No praise sections, no scores, no invented
  metrics.
- **Keep it a procedure, not a persona.** An agent file earns its
  length with steps, calibration and routing. If a section would
  read the same in any repo, delete it.

## Changing the roster

- Delete an agent that is not actually spawned rather than keeping
  it as a maybe. A roster listing work nobody delegates teaches the
  reader to skim the list, and the skim is what makes the useful
  entries invisible.
- Add one only when the work is genuinely context-free and
  fan-out-shaped. Work that depends on the conversation belongs
  inline — a cold agent re-deriving what the session already knows
  costs more than it saves (AGENTS.md §4).
- Run `./scripts/sync-agents.sh` after any change here, so the
  Codex mirror under `.codex/agents/` cannot drift from the
  Markdown. Its `--check` mode is a local convenience for whoever
  maintains that mirror, not an enforced gate: the mirror is
  generated and gitignored, so a fresh clone — CI included — has
  none to check.
- Update this table and, when the roster's shape changes, the §5
  row that points here.
