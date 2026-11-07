---
description: Profile KiwiDesk's test run from evidence — time each target under the gate slot, sample the test helper, tell WAITING from CPU work, count the windows it owns, rank tests serially, measure compile cost, and name the call chains that cost the time. Use when a gate or target got slow, turns bimodal (fast one run, slow the next), a test flakes only under load, or before a minor or major release to compare against the last baseline.
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
  in the GUI target that has been the source-scanning family.
  Rank its suites serially (step 6) and look for the levers that
  have cost it (perf PR on `perf/test-census-scans`, 2026-11-07;
  the nine slowest census suites went 104 s → ~46 s serial):
  - whole-tree work redone per needle or per list —
    `TestScratchCensusTests` collapsed the tree 12×,
    `ShortcutsBespokeContainerTests` built an `Array(source)` of
    the whole tree per order list;
  - a raw `String(contentsOf:)` read bypassing
    `SourceScan.strippedSource(at:)` and its memo;
  - a per-name substring search over a joined tree in a debug
    build — 210 names over 2.3 MB took 11.8 s with Swift
    `firstRange`, 5.9 s with Foundation `contains`, 0.14 s with
    `memmem`;
  - a regex run over files that cannot contain its literal, or
    compiled once per file.

  A changed guard owes `guard-prover` (tests.md).

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
date and the machine, and with the compile numbers beside them:
frontend CPU per test module and the top type-check bodies (step
7). When this is owed, and what a regression then costs a release,
is packaging-and-release.md's.

## 6. Rank tests by cost, serially

```bash
swift test --skip-build --test-product <T> --no-parallel \
  [--filter <suite>] --event-stream-version 0 \
  --event-stream-output-path <out-dir>/events.jsonl
python3 -I .claude/skills/profile-tests/scripts/rank-tests.py \
  <out-dir>/events.jsonl --top 20
```

Run it under `scripts/gate-lock`. Only the `--no-parallel` run
gives a test's cost: in a parallel run its span includes the wait
for the main actor — a median 13 s per test in Core and 55 s in
GUI (measured 2026-11-07) — and ranks queueing, not work.

The first suite to touch `SourceScan`'s memo pays its fill, so a
filtered run moves that cost onto whichever suite runs first. Run
twice, and compare a suite only against itself in the same shape
of run.

## 7. Compile cost

Build into a separate `--scratch-path` in your scratchpad, so the
flags below do not rebuild the main `.build`.

```bash
swift build --build-tests --scratch-path <scratch> \
  -Xswiftc -stats-output-dir -Xswiftc <out-dir>/stats
python3 -I .claude/skills/profile-tests/scripts/frontend-cpu.py \
  <out-dir>/stats
```

prints frontend CPU seconds per module. For the slowest bodies add
`-Xswiftc -Xfrontend -Xswiftc -warn-long-function-bodies=<ms>` and
`-Xswiftc -Xfrontend -Xswiftc
-warn-long-expression-type-checking=<ms>`; each warning names a
body with its `file:line` and milliseconds.

A loaded machine inflates type-check times (`SegmentedPicker`'s
`track` read 1.96 s loaded, 1.47 s quiet, 2026-11-07). Confirm a
hot spot on a quiet machine against the ORIGINAL code first — the
negative control — and measure it again after the fix under the
same conditions.

## 8. Reading the numbers

- **One CI run cannot confirm a compile change.** Test Core's
  compile (the step's time minus its `Test run with` seconds)
  varied ~460–650 s across identical-shape runs (2026-11-07).
  Measure locally with step 7.
- **Micro-benchmark costs do not sum to the real build.** A
  per-macro cost measured in a toy file does not predict the
  target; measure on a real rewrite.
- **Rejected: a shared equality-assertion helper.** Rewriting
  10,156 single-line `#expect(A == B)` in Core tests to a generic
  `expectEqual` cut local Core-tests frontend CPU 1148 → 962 s,
  but CI's Test Core compile (~472 s) sat inside the noise above,
  and tests.md ▸ per-file private helpers forbids a shared
  assertion helper. Do not retry it without a new argument.
- **`@Test` expansion is a floor.** ~15–25 ms per test
  (2026-11-07); no assertion helper touches it.

## What this is not

Not a timing test: tests.md bans tight wall-clock deadlines in the
suite, and the numbers here are one machine's. A regression worth
keeping out for good becomes a guard that COUNTS work (windows,
reads, retiles), proven by `guard-prover`. The `test-profiler`
agent runs this procedure when it is delegated; it reports and
edits nothing.
