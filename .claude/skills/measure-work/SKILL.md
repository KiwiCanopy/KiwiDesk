---
description: Measure the work KiwiDesk does per Space switch on the real desk — build a bundle, swap it in for the running instance, switch Spaces through the CLI idle, with every core loaded and with the GPU held busy, read `get_work_counters`, put the previous build back. Use before and after a change that should make switching or retiling cheaper (#1508 and its follow-ups), to compare two builds, or when a user reports lag while switching.
argument-hint: "[optional: two space names, rounds, or a baseline to compare against]"
---

A performance claim about the engine is a before/after pair of
counter readings from the same desk under the same load, never a
reading of the code. The counters are `WorkMeter`'s
(`Sources/KiwiDeskCore/App/WorkMeter.swift`; its `report`, in
`WorkMeter+Report.swift`, is the one list of what they are); this procedure is how to read them so
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
$S $APP <a> <b> 10 --gpu-load # a WebGL2 shader holding the GPU
```

`--gpu-load` (#2030) is the condition several switch stalls only
showed under (#1925, #1956, #1508). It serves `gpu-load.html`
beside the script on 127.0.0.1 (Safari refuses WebGL from
`file:///private/tmp`), opens it in Safari, and refuses to measure
until `ioreg`'s Device Utilization reads 90 % or more — a
draw-call-bound page such as WebGL Aquarium never gets there on an
M1 Max and is a CPU load in disguise. The run sits inside
`caffeinate -d`, because a display sleeping mid-run zeroes the
trace, and the GPU trace's minimum and mean print to stderr; a
minimum far under 90 means the load lapsed and the run does not
count. Everything it started — server, tab, caffeinate, sampler —
is torn down on exit, Ctrl-C included, since a forgotten full load
skews the next reading. GPU numbers compare only with GPU numbers
from the same machine, like the CPU condition.

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
`ax_calls_per_switch`, `bar_renders_per_switch`, `parks_issued`
and `frames_issued` over `space_switches`, `retile_ms_mean`/`max`,
`queue_wait_ms_max`. Compare a change against its own
before-bundle on the same pair, the same rounds and the same
load, and report the deltas. Three readings to keep straight:

- `space_switches` counts the switch door (`focus_space`, the
  scroll step) and nothing else — not boot, wake or a Desktop
  switch — so a run that is not pure CLI Space switches has no
  per-switch denominator.
- `retile_ms` CONTAINS `bar_ms` and `border_ms`: a saving in the
  bars lowers both, and counting it twice is the mistake.
- the `settle_*` counters are the Space switch settle's SHARE
  of `parks_*`, `frames_*` and `passes_*` (#1964), never added
  to them; `settle_parks_issued` over `space_switches` is what
  the settle re-sends. A `settle_passes_held` or
  `settle_passes_merged` above zero means the motion gate moved
  work out of or into the share, so that run's share is skewed.

`ax_off_main_us_mean` is the per-call cost the load inflates;
`ax_main_*` is what blocks the main actor.

## 6. A release comparison: the fixed desk (#1910)

A per-change pair runs on whatever the desk holds that day, so its
absolute numbers do not carry across days. A release row in
`docs/performance.md` is measured on the fixed desk instead, every
bundle in one sitting:

```bash
F=.claude/skills/measure-work/scripts/fixture-desk.sh
$F up <scratch>/<label>/KiwiDesk.app <scratch>/fx-<label> [extra.lua]
# measure pairs 2↔3, 3↔4 and 5↔6, idle / --load / --gpu-load
$F down <scratch>/fx-<label>
```

The fixture pins only the animation settings every measured
release shares; a setting one release changes or lacks is stated
per bundle in `extra.lua`, which `up` appends to the config — a
*slide off* bundle appends `animations.set_on_space_change(false)`.
Compare like with like: every release with all animations off,
and every release with its Space-switch animation on at one
shared pace, each set through `extra.lua`. Pass `--gap` past the
longest animation measured, or a press cuts it short and the run
reads cheaper than the motion is.

The owner switches to an EMPTY macOS Desktop first, by hand or by
swipe — a `focus_desktop` switch leaves macOS's current Desktop
behind, and the fixture's windows open there instead. `up` replaces
`swap-instance.sh`: it stops the running app before pointing
`~/.config/KiwiDesk` at a Lua-only config, which every release reads
and none migrates, so an older bundle boots the same desk. Run `down`
before the next bundle's `up`; every bundle starts on a fresh copy.

Runs per condition follow §3; when more are added, balance their
ORDER across the bundles, since a long GPU sitting heats the
machine and the later bundle pays for it. Report counters only:
a `frame clock stalled` count is no comparison across releases,
since it fires only while the window-animation clock runs and a
release whose switch pass is instant never starts it.

Then add the release's own section to `docs/performance.md` —
one table per pair, a row per bundle and load, the date, macOS
version and commits named above it — measuring the previous
release again in the same sitting, since times compare only
within a table. `docs.md`'s row for that page says what may never
change in an earlier section.

## What this is not

Not a test: the numbers are one desk's, and tests.md bans timing
assertions. A saving worth keeping becomes a guard that COUNTS the
work in a fixture (#1884's shape), proven by `guard-prover`. The
`work-profiler` agent runs this procedure when it is delegated; it
reports and edits nothing.
