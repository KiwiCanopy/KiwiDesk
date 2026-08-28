---
paths:
  - ".claude/rules/**"
  - ".claude/agents/**"
  - "AGENTS.md"
---

# Writing a rule

Canonical for the rule files themselves (AGENTS.md §5 indexes
it). It loads when you edit one, which is the only moment it
binds.

## Write an obligation, not a state claim (#614)

An **obligation** — *"route a user-facing condition through
structure the GUI renders"* — cannot become false. It can only be
*violated*, and a violation is a code-review event.

An **absolute claim about the current tree** — *"Core holds no
`L()` call site outside `Localization/`"*, *"this map is the one
copy"*, *"Core currently holds…"* — is true only the day it is
written. The commit that falsifies it is somewhere else entirely,
so nothing notices. That one shipped false (Core had carried an
`L()` call outside `Localization/` for over a week already) and
survived the review that introduced it (#601).

This matters more than ordinary doc drift because these files
load as **instructions**. An agent reads the claim as fact and
reasons from it without checking — which is exactly how #601
guarded the wrong axis: the rule said the problem was `L()` call
sites, so the guard counted `L()` call sites, while the real
defect was hardcoded English that never went near `L()`.

## What to do with one

Ranked. Take the first that fits; **delete is the last resort**,
not a peer of the others.

1. **Name its enforcing guard inline** — a suite name or a
   `scripts/…` path. The best rows already do: `VisibleBoundsRoutingTests`, `SettingsCodingTests`,
   `LocalizationRegistryTests`, `ResourceBundleRoutingTests`,
   `SpringStabilityMarginTests`.

   A test **function** name is a fine *addition* when it is the
   precise answer — but never the whole citation.
   `RuleCitationTests` resolves suite names and `scripts/…`
   paths, so those cannot rot silently; a bare function name is
   not machine-checked, because nothing about its shape
   distinguishes it from the production symbols these files cite
   constantly. Name the suite, then add the function.

   Note what a resolved citation does and does not prove: that
   the guard still *exists*, not that it still guards what the
   sentence says. A rename is caught; gutting a suite and keeping
   its name is not.
2. **Rewrite it as an obligation** — say what a future author must
   do, not what the tree currently is.
3. **Re-home the fact to a named authority** and cite that
   instead. The authority does not have to be a test: a script's
   docstring, a type's stored properties, another rule file that
   owns the table. Verify it actually carries the *whole* fact
   before nominating it — nominating an authority that covers
   half of what you point at is the same failure one level down.
4. **Scope it to when it was observed.** Claims about the world
   outside this repo — macOS behavior, Apple tooling, a vendor's
   plan limits, a device measurement — cannot be guarded and are
   still worth keeping. Say when they were seen.
5. **Leave it, if it sits beside its own register.** The test is
   the mechanism, not the file boundary: **would an author adding
   an entry have the count on screen?** If yes it is
   self-correcting; if they would have to go looking, it is not.
   The register also has to be a list *in this document* — a
   count of things a script defines is disposition 3, however
   close the prose sits. `core-boundaries.md` is the worked
   example, and it writes its own justification inline — its
   opening count says it is "the … bullets immediately below",
   naming the register rather than a number this file would then
   hold a second copy of. A heading
   twenty-six lines above its table fails this even though both
   are in one file — that was `borders.md`'s "Three writers",
   and it was wrong.
6. **Delete it.** Only when none of the above fits.

A **past-tense fact** is not a state claim and needs none of
this: *"four `ConfigIssue` messages shipped that way until
#601"* cannot rot.

## Two rules about the guards themselves

**A number-pin must derive the number, not restate it.** Pinning
a count by hand-listing it in a test moves the copy, it does not
guard it — the test and the prose now agree with each other and
with nothing else. `SpringStabilityMarginTests` computes the
margin from the shipped `maxStableStep`; `LocalizationRegistryTests`
reads the registry. A `#expect(list.count == 5)` over a literal
array is a tautology.

**Prove a new guard reds.** Revert the thing it protects and watch
it fail before you trust it. Several here have passed vacuously on
their first draft, including one pinned at the single duration
where an unrelated net rescued the bug it named.

The sharpest instance, because it survived review three rounds
running: a guard that matched a **regex against source** and
matched nothing, so it passed for having found no violations
rather than for there being none. A guard over generated or
rendered output reads the **built artifact** or uses a parser, and
asserts its input is non-empty before asserting anything about it.

**A refinement to a needle states what it TRADES, not only what
it buys.** Narrowing a needle, adding a boundary, tightening a
match — each buys one case and costs another, and the cost is
what the NEXT prover round finds, because a refinement documented
by its win alone leaves nothing for a reader to check against.

#1069 ran that loop three times, each fix opening the hole the
one after it found. Narrowing `symbolEffect` to `symbolEffect(`
stopped a disabling spelling firing and re-opened the whitespace
fail-open the walk exists for — `.symbolEffect (…)` compiles.
Adding a leading identifier boundary then fixed a false positive
and blinded every DOT-prefixed needle to its own receiver, so
`field.animation(…)` written inline went unscanned; that one
weakened the older, load-bearing guard next door, and the site
counts did not move by one, because the tree happened to write
every call at the start of a chain line.

So the cost goes in the docstring beside the refinement, in the
same change — not the commit message, which the next reader is
not holding. Where the cost is a class the guard now mis-fires
on, name the class; where it is a shape the guard can no longer
see, name the shape. A refinement whose trade you cannot state
is one you have not finished working out.

## State a fact once

A count or a list copied into a second file rots in both on one
commit, and neither copy knows the other exists. Name the
authority and link to it.

This does **not** contradict the tripwire exception in AGENTS.md
("How this file is organized"), which repeats a handful of §5
guardrails verbatim in their rule file. That exception covers
*obligations*, and an obligation repeated verbatim cannot go out
of sync with itself. A **fact** — a count, a file list, a
measured number — is what must not be duplicated.

One narrow extension, on the tripwire's own reasoning: a
**danger fact**, whose cost of not knowing it is destructive,
earns a copy at the seam where someone would act without it.
`input-and-animation.md` repeats that `KIWIDESK_NO_WS_TRACKING`
kills a production fast path, because `tests.md` owns that table
and does not load while you are editing `Animation/`. Copy the
danger, not the table.

## Scope

All of the above binds `.claude/rules/*.md`, AGENTS.md and
`.claude/agents/*.md`. The agent files are in scope for the same
reason the rule files are — they load as instructions, an agent
reasons from a claim in one without checking it, and
`RuleCitationTests` resolves their citations alongside the rest.
[subagents.md](subagents.md) owns what is additionally true of an
agent file.

It applies to a **Swift doc comment** too whenever that comment
argues from numbers: the #599 stability margins lived in
`Spring.swift`, were load-bearing, and were guarded by nothing
until #614.
