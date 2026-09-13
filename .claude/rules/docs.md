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
| `docs/user-guide.md` | The Settings app & GUI flows |
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

The Settings window explains itself: every row has a label, most
carry a caption, and a `?` opens a help text. A user doc that
re-explains a row competes with the caption and loses — the
caption is beside the control, the doc is not, and the two drift
apart on the first retune. So a user-facing doc (`user-guide.md`,
`spaces-and-desktops.md`, `cli.md`, `lua-reference.md`,
`accepted-limitations.md`, `index.md`) is written to a budget:

- **One fact per sentence, and each fact once.** A behaviour the
  doc has already stated is not restated in the next section
  with different words; link the section that owns it.
- **Name the control, state what the row cannot say, stop.** The
  caption and the `?` are the primary home for *what this row
  does*. The doc adds what they cannot carry: how rows interact,
  where a thing lives, the keyboard path, a limit, a value the
  caption does not show. A paragraph whose every sentence is
  already on the row is deleted, not shortened.
- **What, never why.** The argument for a behaviour lives in
  `design-decisions.md` (its charter is below). A user doc does
  not say "deliberately", "which is why", "rather than", or name
  the alternative that was rejected — unless the why *is* the
  instruction ("do this before opening Settings").
- **No history.** No "used to", "until #N", "since #N", "before
  this version", and no issue numbers at all: a reader of the
  user guide has no issue tracker in front of them. Past tense
  is for the changelog.
- **No narration.** Nothing about the doc itself, the design's
  intent, or what the reader will find worth knowing — the
  sentence that follows such a clause is the one that carries
  the fact; keep that one.
- **Every fact survives.** A cut that drops a control name, a
  value, a range, a default, a chord, a path, a limitation or a
  cross-link is a defect, not a trim. Code and docs must never
  describe different behaviour, and a doc that falls silent on a
  behaviour describes it as absent.

The style is adapted from the Caveman compression rules, whose
own guidance is to drop the compression for anything a
non-team-member reads: the budget cuts *restatement*, never
articles or verbs, and the result is ordinary readable prose. A
contributor doc (`architecture.md`, `ui-patterns.md`,
`translating.md`, `localization-naming.md`) takes the same budget
with one exception, `design-decisions.md`, whose charter is to
argue — there the budget cuts repetition and event-logging and
never the argument.

The same discipline applies to a code comment through AGENTS.md
§2.8, which owns that half.

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
