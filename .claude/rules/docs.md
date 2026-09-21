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
| `docs/index.md` | The docs landing map — and, because it also carries install and upgrade prose, it is a **second home for claims `README.md` makes**. Change one, check the other in the same change set: an upgrade claim was corrected in the README and left standing here (#661's branch), which is what an unowned page does |
| `docs/lua-reference.md` | Lua config & behavior, in *expects → does → example* form |
| `docs/user-guide.md` | What the GUI cannot answer about the Settings app — admission is the owner's ruling (Prose budget, below) |
| `docs/spaces-and-desktops.md` | How screens, macOS Desktops, profiles and KiwiDesk Spaces relate — the user-facing mental model, not a flow and not a pipeline |
| `docs/cli.md` | Commands, events, IPC |
| `docs/recipes/` | Integration recipes |
| `docs/architecture.md` | End-to-end pipelines at directory altitude |
| `docs/design-decisions.md` | Durable product/UX decisions (see charter below) |
| `docs/ui-patterns.md` | Shared Settings control conventions |
| `docs/accepted-limitations.md` | Behavior classified accepted-by-architecture |
| `docs/translating.md` | Translation workflow |
| `Sources/KiwiDeskCore/Resources/Locales/TRANSLATION_BRIEF.md` | The mechanical contract handed to a translator, and only that — it sits beside the catalogs because that is what gets handed over. Guidance routes to `docs/translating.md`; it went unowned long enough to ship a per-locale key count that was wrong by dozens, so it states no number `en.json` already answers |
| `docs/localization-naming.md` | The feature-name / mode-name guard pair |
| `plan/` | When the design itself shifts (gitignored — never cite it from source or `docs/`) |

## Prose budget (#1395)

A user-facing page answers a question the GUI cannot. Leave what
a row's caption or `?` says to the row: the doc names the control
and states only what the row cannot carry — how rows interact,
where a thing lives, the keyboard path, a limit, a value the
caption does not show. A paragraph whose every sentence is on the
row is deleted, not shortened. The budget, as obligations:

- **One fact per sentence, and each fact once.** Link the section
  that owns a behaviour instead of restating it.
- **What, never why.** The argument lives in `design-decisions.md`
  (charter below); a user doc does not say "deliberately", "which
  is why", "rather than", or name the rejected alternative —
  unless the why *is* the instruction ("do this before opening
  Settings").
- **No history.** No "used to", "until #N", "since #N", and no
  issue numbers in `user-guide.md` or `spaces-and-desktops.md`;
  past tense is the changelog's. A reference page (`cli.md`,
  `lua-reference.md`) and the limitations table may cite the
  issue that tracks a limitation or its fix, since that is where
  a reader follows it — `accepted-limitations.md`'s Why column is
  its charter, not a violation.
- **No narration** about the doc itself or the design's intent.
- **Every fact survives a budget cut.** Within a section the
  owner has admitted, a cut that drops a control name, a value, a
  range, a default, a chord, a path, a limitation or a cross-link
  is a defect, not a trim; a doc that falls silent on a behaviour
  describes it as absent. Removing a section WHOLE is not a
  budget cut but an admission ruling (next paragraph), which
  takes its facts with it because the GUI carries them.

**Admission is the owner's ruling, not the author's.** Whether a
setting or surface belongs in the user guide at all is judged by
"is this clear from the GUI?", and the owner judges it: an agent
documenting a new setting or surface ASKS before adding a guide
section, and the default answer is no entry — the row's caption is
its documentation (owner ruling 2026-09-13). A contributor page
(`architecture.md`, `ui-patterns.md`, `translating.md`,
`localization-naming.md`) has no admission gate.

A page — user-facing or contributor — is held to the budget once
its sweep has landed: swept so far, `user-guide.md` (#1395),
`localization-naming.md` (#1404), `cli.md` (#1397); every other
page is swept by its own audit under collector #1406, and
`docs/recipes/` joins when its audit is filed. Extend the swept
list here in the same change set as the sweep.

The style is adapted from the Caveman compression rules (seen
2026-09-13), whose own guidance is to drop the compression for
anything a non-team-member reads: the budget cuts *restatement*,
never articles or verbs, and the result is ordinary prose. The
one exception is `design-decisions.md`, whose charter (below) is
to argue. The same discipline applies to a code comment through
AGENTS.md §2.8, which owns that half.

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

**A block describing behavior no release has yet carries
`:::unreleased` in the same change set that writes it.** The site
auto-deploys from `main`, so the page otherwise describes `main`
to a reader running the last release. The marker takes no version
and is retired for you at the next release —
[site.md](site.md) ▸ *Unreleased docs mark themselves* owns the
whole argument, and it is stated here because that file does not
load for whoever edits `docs/**`.

## `docs/accepted-limitations.md`

When a review or manual pass classifies a behavior as
**accepted-by-architecture**, it adds a row here in the same
change set — the user-facing twin of the AGENTS.md §5 guardrail
rule.
