---
paths:
  - ".claude/rules/**"
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

1. **Name its enforcing guard inline** — a suite name, a
   `scripts/…` path, or a test function name. The best rows
   already do: `VisibleBoundsRoutingTests`, `SettingsCodingTests`,
   `LocalizationRegistryTests`, `ResourceBundleRoutingTests`,
   `SpringStabilityMarginTests`.

   **Always name the suite, even when a function name is the
   precise answer.** `RuleCitationTests` resolves suite names and
   `scripts/…` paths, so those citations cannot rot silently; a
   bare function name is not machine-checked, because nothing
   about its shape distinguishes it from the production symbols
   these files cite constantly. Name the suite and add the
   function for precision.
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
5. **Leave it, if it sits beside its own register.** A count
   immediately above the list it counts is self-correcting: a
   reader can see both at once, and an author adding an item is
   looking at the number. "Two env levers" over a two-row table
   is fine; a count in a *different* file from its list is not.
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

## Scope

All of the above binds `.claude/rules/*.md` and AGENTS.md. It
applies to a **Swift doc comment** too whenever that comment
argues from numbers: the #599 stability margins lived in
`Spring.swift`, were load-bearing, and were guarded by nothing
until #614.
