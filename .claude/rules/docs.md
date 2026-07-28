---
paths:
  - "docs/**"
---

# Documentation

Canonical for this subsystem (AGENTS.md §3, the Document step,
indexes it). Any user-visible behavior change updates the matching
doc **in the same change set** — code and docs must never describe
different behavior.

| File | Owns |
|---|---|
| `docs/lua-reference.md` | Lua config & behavior, in *expects → does → example* form |
| `docs/user-guide.md` | The Settings app & GUI flows |
| `docs/cli.md` | Commands, events, IPC |
| `docs/recipes/` | Integration recipes |
| `docs/architecture.md` | End-to-end pipelines at directory altitude |
| `docs/design-decisions.md` | Durable product/UX decisions (see charter below) |
| `docs/ui-patterns.md` | Shared Settings control conventions |
| `docs/accepted-limitations.md` | Behavior classified accepted-by-architecture |
| `docs/translating.md` | Translation workflow |
| `docs/localization-naming.md` | The feature-name / mode-name guard pair |
| `plan/` | When the design itself shifts (gitignored — never cite it from source or `docs/`) |

## `docs/design-decisions.md` charter

A durable product/UX decision a contributor would otherwise
re-litigate or undo — a **Principle, Rationale, Trade-off, or
Map**, per that file's charter. Never an event log, never a
restatement of current behavior, never "who got it wrong". An
entry argues why the rule is right and what breaks without it.

OS-blocked-by-SIP items are a separate class kept here, with no
in-app escape hatch.

Every docs page needs Starlight frontmatter or the site build
breaks. A new page also needs a sidebar entry — see
[site.md](site.md).

## `docs/accepted-limitations.md`

When a review or manual pass classifies a behavior as
**accepted-by-architecture**, it adds a row here in the same
change set — the user-facing twin of the AGENTS.md §5 guardrail
rule.
