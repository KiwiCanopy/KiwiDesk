---
description: Measure the work KiwiDesk does per Space switch on the real desk — build a bundle, swap it in for the running instance, switch Spaces through the CLI idle and with every core loaded, read `get_work_counters`, put the previous build back. Use before and after a change that should make switching or retiling cheaper (#1508 and its follow-ups), to compare two builds, or when a user reports lag while switching.
argument-hint: "[optional: two space names, rounds, or a baseline to compare against]"
---

A performance claim about the engine is a before/after pair of
counter readings from the same desk under the same load, never a
reading of the code. The counters are `WorkMeter`'s
(`Sources/KiwiDeskCore/App/WorkMeter.swift` — its `report` is the
one list of what they are); this procedure is how to read them so
two readings compare.

The tools are in `scripts/` beside this file. Write every output
to your scratchpad, never into the worktree.

## 1. Build the bundle

```bash
scripts/build-app.sh --output <scratch>/<label>
```

Release configuration, signed with the identity the Accessibility
grant is tied to. It takes the gate slot; when another session's
suite holds it, wait (`verify-gate` ▸ Fast inner loop). A
"before" reading needs a bundle built from the commit BEFORE the
change, not the running app: the counters exist only from #1508's
P0 on, and an older build answers `unknown command`.

## 2. Swap it in

```bash
.claude/skills/measure-work/scripts/swap-instance.sh start \
    <scratch>/<label>/KiwiDesk.app <scratch>/swap.state
```

It records whatever KiwiDesk is running, stops it by its own path
and opens yours. Another session's build may be the one running:
the script never matches a generic pattern, and whose build you
replaced goes in your report. If the stop times out, a modal sheet
is holding the app — tell the owner, never force-kill.

## 3. Pick the pair and measure

Read `get_state` first and pick two Spaces on the SAME screen that
both hold windows (on a two-screen desk the allocation is not the
obvious one). Record the window count per Space: the per-switch
numbers scale with it, so a reading without it does not compare.

```bash
S=.claude/skills/measure-work/scripts/measure-switches.sh
APP=<scratch>/<label>/KiwiDesk.app
$S $APP <a> <b> 10            # idle
$S $APP <a> <b> 10 --load     # one `yes` per core
```

Ten rounds is twenty switches, each with its settle. Run each
condition twice; a pair that disagrees by more than a quarter is
noise, so take a third. Leave the desk alone while it runs — a
window opened mid-run is counted.

## 4. Put the previous build back

```bash
.claude/skills/measure-work/scripts/swap-instance.sh restore \
    <scratch>/swap.state
```

Always, including after a failed step: the owner's desk runs on
whatever was there before.

## 5. Read the numbers

The per-switch figures are the ones that answer #1508:
`ax_calls_per_switch`, `parks_issued` and `frames_issued` over
`space_switches`, `retile_ms_mean`/`max`, `queue_wait_ms_max`.
Compare a change against its own before-bundle on the same pair,
the same rounds and the same load, and report the deltas.
`ax_off_main_ms_total` divided by the call count is the per-call
cost the load inflates; `ax_main_ms_*` is what blocks the main
actor.

## What this is not

Not a test: the numbers are one desk's, and tests.md bans timing
assertions. A saving worth keeping becomes a guard that COUNTS the
work in a fixture (#1884's shape), proven by `guard-prover`. The
`work-profiler` agent runs this procedure when it is delegated; it
reports and edits nothing.
