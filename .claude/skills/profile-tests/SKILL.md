---
description: Profile KiwiDesk's test run from evidence — time each target under the gate slot, sample the test helper, tell WAITING from CPU work, count the windows it owns, and name the call chains that cost the time. Use when a gate or target got slow, turns bimodal (fast one run, slow the next), a test flakes only under load, or before a minor or major release to compare against the last baseline.
argument-hint: "[optional: KiwiDeskCoreTests | KiwiDeskGuiTests | a suite filter]"
---

A slow test run has a mechanism, and the mechanism is measured,
never guessed: #1868 looked like CPU contention, its first fix was
a parallelism cap, and the cap changed nothing — the helper was
waiting on WindowServer with the CPU idle, behind 700+ panels the
test cores had leaked. Take the steps in order; each one rules a
class of cause in or out.

The tools are in `scripts/` beside this file. Run everything from
the worktree root on a tree built with `swift build --build-tests`.

## 1. Time each target, alone, under the gate

```bash
.claude/skills/profile-tests/scripts/profile-run.sh KiwiDeskCoreTests <out-dir>
```

It runs the target through `scripts/gate-lock` (one heavy run on
the machine at a time — tests.md explains why parallel runs are
noise), records the helper's window census every 20 s, and takes
two `sample`s 60 s apart once the run passes `--sample-after`
(150 s by default; set it below the target's FAST time so a fast
run is sampled too). Its summary is the wall time, the
`Test run with` line and the last window counts.

Run each target at least twice. One number says nothing about a
bimodal target, and a mode is a property of a run, not a commit.

## 2. Waiting or working?

```bash
.claude/skills/profile-tests/scripts/attribute-sample.py <out-dir>/sample-a.txt
```

and read `ps.txt` beside it.

- **Main thread mostly blocked in `mach_msg`, process CPU low**:
  the run is WAITING — on WindowServer when the entries are
  `SLS…` / `_NX…` / `CG…`. More cores and a parallelism cap do
  nothing here. Read the test-module frames above the waits:
  those are the reads to seam (tests.md ▸ a WindowServer read on
  a per-retile path) or the windows being created.
- **Helper near `cores × 100 %`, little blocking**: the run is
  WORKING. The "busiest frames, CPU only" list names the code;
  in the GUI target that has been the source-scanning family,
  where a cache or a cheaper walk is the lever.

## 3. Count the windows it owns

`windows.txt` is the census over time; `shapes.txt` groups the
windows by layer and size at the sample mark. A count that rises
and falls is tests in flight. **A count that only climbs is a
leak**: a panel owner without its `isolated deinit`
(core-boundaries.md), or a new window kind nothing tears down. The
shapes name it — a full-width strip at the bar's thickness is a
shelf, a small square a sticky mark.

## 4. Prove the fix on a rebuilt binary

Change one thing, `swift build --build-tests`, run step 1 again.
**Rebuild after every mutation or restore before measuring**: a
run on a stale binary reads as "the fix did nothing", and #1868
lost an hour to exactly that. A fix that changes a guard still
owes `guard-prover` (tests.md).

## 5. Before a minor or major release

Compare against the previous release's baseline — per-target wall
time over two runs, the slowest suites from `run.log`, the peak
window count — kept privately in `plan/test-baseline.md`. A target
25 % slower or a window count that climbs again is investigated
before the cut. Record the new numbers there afterwards, with the
date and the machine. The obligation itself is
packaging-and-release.md's.

## What this is not

Not a timing test: tests.md bans tight wall-clock deadlines in the
suite, and the numbers here are one machine's. A regression worth
keeping out for good becomes a guard that COUNTS work (windows,
reads, retiles), proven by `guard-prover`. The `test-profiler`
agent runs this procedure when it is delegated; it reports and
edits nothing.
