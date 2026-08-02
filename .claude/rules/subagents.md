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

As observed when it was retired, the generic bodies invented gates
the project had never adopted — coverage percentages, complexity
ceilings — so the appended block spent its opening paragraph
cancelling them. They addressed a "context manager" agent that does
not exist, declared MCP tools that do not resolve here, and closed
with a template delivery line quoting an invented quality score.
Sixteen of eighteen carried no KiwiDesk context at all, and several
described stacks this repo does not contain.

The append was worse, because it worked by copying rules out of
their owning files into an artifact nothing regenerated. As found
on 2026-08-02, the generated `code-reviewer` on disk still said a
profile owns tiling **only**, though `bcfb3d26` had corrected the
context block it was copied from to tiling **plus sparse behavior
overrides** on 2026-07-28. The last commit to touch the installer
before that was `7ddc105f` (2026-07-19), when copy and source did
still agree — so the artifact had gone at least four days stale,
and was around nine days old, before anyone noticed.

Those dates are the floor, not the measurement: the copy was
gitignored, so neither its age nor a regeneration left any trace
to check. That is the actual defect. The window could have been
zero and the shape would still be wrong — nothing could have told
you either way.

That is the shape to avoid, and it is why the fix is not "keep the
copies in sync". An agent definition is repo policy: keep it in
git, next to the rules it enforces, write it by hand, and have it
point at the rule rather than restate it.

## The roster

The directory is the truth; this table is the index. When they
disagree, the row is what to fix. Adding or editing an agent loads
this file, so keep the table current in the same change.

Deleting or renaming one does **not** load it — the loader has no
file to match — and that is where a roster rots. Open this table
by hand whenever you remove an agent.

| Agent | Domain | Posture |
|---|---|---|
| `code-reviewer` | A diff, at the line | judges |
| `architect-reviewer` | A diff, at the seam | judges |
| `guard-prover` | Tests, guards, canaries, assertions | mutates and restores |
| `swift-expert` | Swift, SwiftUI, AppKit, concurrency | advises, edits on hand-off |
| `ui-designer` | The Settings app's surfaces | judges |
| `docs-steward` | `docs/`, rule files, `AGENTS.md` | audits or authors |
| `localization-auditor` | `L()` sites and the locale catalogs | audits or authors |
| `site-engineer` | `site/` and its shipped output | audits or authors |

The column is the agent's territory, deliberately not its trigger.
**When** to reach for one is the `description` field, which is what
actually routes and therefore the only copy that can be wrong
without anyone noticing; inside a review round it is the
`review-change` lane gate. Do not add a third statement of it here.

## Writing an agent file

- **Route, never restate.** An agent points at the owning
  `.claude/rules/*.md` and reads it; it does not carry a copy of
  the rule. A copy is a second live statement that goes stale, which
  is exactly how the retired setup failed.
  [rule-authoring.md](rule-authoring.md) covers agent files — see
  its Scope — so everything it says about a claim in a rule file
  binds a claim in an agent file too.
- **Where "route" and "calibrate" collide, split on kind.** An
  agent's most useful section is what *not* to flag, and some of
  that reads like the rule it is calibrating against. The line is
  the one `rule-authoring.md` already draws: an **obligation** may
  be repeated verbatim, because a copy of an obligation cannot go
  out of sync with itself. A **fact** may not — a count, a list, a
  threshold, a tool inventory, a named exemption. Those get a
  pointer, and if the pointer has nowhere to land, the fact is
  missing from its rule file and that is the bug to fix.
- **Derive, never pin.** Where a number or a set is unavoidable —
  a locale list, a language version, a platform floor — say which
  file to read it from. A pinned count is wrong on the commit that
  changes it, and nothing notices.
- **The `description` is the routing key.** It decides whether the
  agent is ever selected, so write it as *when to use this*, in the
  third person, naming concrete triggers. A description that
  describes the agent's expertise instead of its trigger will not
  route. The frontmatter `name` must equal the filename — Claude
  Code routes on the former and the mirror is written from the
  latter, so a mismatch ships a roster answering to a name nobody
  calls; `sync-agents.sh` refuses it.
- **Give the fewest tools that let it finish.** An agent whose
  posture in the roster above is *judges* gets no `Write` or
  `Edit` — the retired reviewers held both, which bought nothing
  and let a reviewer rewrite what it was judging. One that also
  authors keeps them and declares audit mode in its own body.
  Frontmatter `tools:` does **not** cross into the Codex mirror:
  `scripts/sync-agents.sh` emits name, description and body only,
  and as of 2026-08-02 the Codex agent format had no field to
  carry it. So an agent that must not edit says so in its prose
  as well — that is what survives the crossing.
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
  Codex mirror under `.codex/agents/` cannot fall behind the
  Markdown the way the retired generated agents did. Two limits
  the script states in its own header and cannot close: the mirror
  carries name, description and body but not `tools:`, and its
  `--check` mode is a local convenience for whoever maintains the
  mirror rather than an enforced gate — the mirror is generated and
  gitignored, so a fresh clone, CI included, has none to check.
- Update this table and, when the roster's shape changes, the §5
  row that points here.
