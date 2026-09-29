---
description: Read KiwiDesk's unified log without drowning in it — pick the right process, filter to KiwiDesk's own subsystem, cut a time window around the event, and capture a fresh reproduction with a window poller beside the log. Use whenever the owner reports "X doesn't work with KiwiDesk", a defect needs its mechanism proven from the log, or a previous look came back "too noisy".
argument-hint: "[optional: app name or window id the report is about]"
---

Every KiwiDesk process logs to the unified log under the
subsystem `com.kiwicanopy.kiwidesk`, category `core`, through
`CoreLog` (core-boundaries.md owns the seam). The log is not
noisy; an unfiltered read of it is. A process's log is mostly
AppKit, LaunchServices and icon-services chatter — 3,876 lines
for five minutes in the #1787 read, **72** of them KiwiDesk's.
Take the steps in order; each one removes a class of noise.

## 1. Pick the process

Several KiwiDesk builds are usually alive: the owner's, other
sessions' device builds from their scratchpads, and
`swiftpm-testing-helper` from a parallel test run, which writes
the SAME subsystem with fixture lines ("window 1", "test.kiwi…")
that read like the app misbehaving.

```bash
pgrep -fl 'KiwiDesk.app/Contents/MacOS/KiwiDesk'
```

The one the owner is using is the one whose windows it manages;
`kiwidesk --version` names the CLI's build, which need not be the
running app's. When a report spans a relaunch, the earlier pid
matters too — step 3 prints the pid per line.

## 2. Filter by predicate, never by grep

```bash
/usr/bin/log show --last 30m --info --style compact \
  --predicate 'processID == <pid> AND subsystem == "com.kiwicanopy.kiwidesk"' \
  | sed 's/^[0-9-]* //; s/ Df KiwiDesk.*KiwiDesk: / /'
```

`grep com.kiwicanopy.kiwidesk` is NOT the same filter: every
LaunchServices line quotes the bundle id, and they come back
with you. The `sed` strips the date and the process prefix, so a
line is `time message`. For a live capture use `log stream` with
the same predicate, started BEFORE the owner reproduces.

## 3. Find the anchor, then cut a window

Search every build at once for the thing reported — an app name,
a bundle id, a window id — and let the pid column tell the
builds apart:

```bash
/usr/bin/log show --last 6h --info --style compact \
  --predicate 'subsystem == "com.kiwicanopy.kiwidesk" AND eventMessage CONTAINS[c] "<app>"'
```

Then read EVERYTHING the process logged from a few seconds
before the first hit to a few seconds after the last — the lines
that explain an event rarely name its app. `awk '$1>="19:30:10"
&& $1<="19:30:20"'` over step 2's output does it.

A window id in the log (`w834546`) is its `CGWindowID`, the same
number the poller below and `kiwidesk get_state` print — that is
what joins the three.

## 4. Capture a fresh reproduction

A cold log answers "what happened"; it rarely shows the window's
geometry. Before asking the owner to reproduce, start in the
background:

- the `log stream` of step 2, into a scratchpad file;
- `scripts/poll-windows.swift` beside this file, compiled once —
  one app's on-screen windows (id, layer, frame, title), printed
  only on change with the age of the previous line;
- and, once the window exists, `scripts/ax-windows.swift <pid>`
  for its role, subrole and AX frame, which is what KiwiDesk's
  float and ignore verdicts read.

Then tell the owner exactly what to do and what to report,
wait on the poller's file growing rather than on a sleep, and
read all three together. `kiwidesk get_state` says whether
KiwiDesk tracks the window, in which Space, and whether it
floats.

## 5. Read the verdict lines

Most defects end in one line where KiwiDesk DECIDED something.
Search step 2's output for the verdict, then name its owner —
the line's wording is the text of an `onLog` call, so grep it in
`Sources/KiwiDeskCore` to land on the deciding code, and follow
AGENTS.md §5 to the rule file that owns that code. The verdicts
that most often turn out to be the defect:

- `focus: wN … distrusted; re-asserting wM`, `… reverted to`,
  `… dropped` — a focus report KiwiDesk refused. The window the
  owner wanted goes behind the one it re-asserts.
- `close distrust`, `gone: … closed` — a removal refused or
  classified.
- `size bound …` — the #677 learner deciding an app's limit.
- `slow reconcile` / `slow attach` — an app answering AX late;
  context for timing, rarely the cause.

## Traps

- A probe that prints only on change hides the NEXT event's
  onset; read the `(+age)` column before pairing a burst with the
  event above it.
- A line that never appears was either never reached or never
  written: a GUI-side `NSLog` is redacted to `<private>`, and a
  seam nobody wired never reaches the sink (core-boundaries.md).
- A reproduction that shows the defect on the unfixed build and
  "not" on the fixed one proves nothing until the unfixed build
  is shown to reproduce it in the same sitting.
- Quote the log lines that prove a mechanism in the issue or to
  the owner BEFORE implementing a fix for it.
