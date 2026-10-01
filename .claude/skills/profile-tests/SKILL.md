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

It takes the gate slot first (`verify-gate` ▸ Fast inner loop
owns why), so its clock starts at acquisition — and the run is
niced, as every gate step is, so compare only niced times — then
records the helper's window
census every 10 s and samples it at `--sample-after` (150 s by
default) and again 60 s later if the helper is still running. Set
`--sample-after` well below the target's FAST time, or a fast run
is never sampled. Its summary is the wall time, the
`Test run with` line and the peak on-screen window count.

`run.log`'s "Suite X passed after N seconds" is when X FINISHED,
counted from the start of a run that starts nearly every suite at
once — the last finishers, not the most expensive suites. Read it
only as "who queued longest", and take cost from the samples.

Run each target at least twice. One number says nothing about a
bimodal target, and a mode is a property of a run, not a commit.

## 2. Waiting or working?

```bash
.claude/skills/profile-tests/scripts/attribute-sample.py <out-dir>/sample-a.txt
```

and read `ps.txt` beside it FIRST: the main thread's blocked
share means something only for a main-actor-bound target. A helper
near `cores × 100 %` is working, and its main thread is merely
parked in the test runner — the script prints that as one chain
into `main`.

- **Main thread mostly blocked in `mach_msg`, process CPU low**:
  the run is WAITING — on WindowServer when the entries are
  `SLS…` / `_NX…` / `CGS…`. More cores and a parallelism cap do
  nothing here. Each wait chain names the innermost KiwiDesk frame
  with its `file:line` and the WindowServer entry it waited in —
  "KiwiDesk frame" includes production code, which the test binary
  links. Those are the reads to seam (tests.md ▸ a WindowServer
  read on a per-retile path) or the windows being created.
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
time over two runs, waiting or working, the top wait chains and
CPU frames, the peak window count. It lives privately in the
owner's main checkout at `plan/test-baseline.md`, which a worktree
cannot see, so the caller hands it in. **A regression is** a
target 25 % slower over two runs, a mode that flipped (waiting ↔
working, or a target turned bimodal), or a window count that
climbs again. Record the new numbers there afterwards, with the
date and the machine. When this is owed, and what a regression
then costs a release, is packaging-and-release.md's.

## What this is not

Not a timing test: tests.md bans tight wall-clock deadlines in the
suite, and the numbers here are one machine's. A regression worth
keeping out for good becomes a guard that COUNTS work (windows,
reads, retiles), proven by `guard-prover`. The `test-profiler`
agent runs this procedure when it is delegated; it reports and
edits nothing.
