---
title: Performance
description: What a Space switch costs, release against release, measured on one fixed desk.
---

# Performance

What a Space switch costs KiwiDesk, measured the same way for
every release that changes it so the rows compare. This page holds
the newest comparison; earlier ones are linked at their release's
tag. Counts — accessibility calls,
windows parked — come from the desk and move little with load;
times are one machine's and carry its noise, so compare them only
within a table.

## How it is measured

- **The desk.** A fixed set of windows on one screen, one layout
  per Space: 3 TextEdit in bsp, 2 TextEdit and 2 VS Code in
  scrolling (two columns scrolled out), and Script Editor: 2
  floating, 3 in stack and 3 in monocle. The config is a Lua file
  every release reads, with every animation setting both releases
  share pinned to its default.
- **The run.** Ten round trips between two Spaces (20 switches),
  each pair measured idle, with every core busy, and with the GPU
  held at 90 %+ by a WebGL shader. Each cell is the mean of at
  least two runs; a maximum is the median of the runs' maxima.
- **The machine.** Apple M1 Max, one screen. Each comparison
  names the macOS version it ran on.

The procedure and the desk script live in the repository's
`measure-work` skill.

## Columns

| Column | Meaning |
|---|---|
| AX calls | Accessibility calls to other apps per switch |
| Parks | Windows moved to the hiding corner per switch |
| Retile mean / max | Main-thread time of one layout pass, ms |


## 3.0.0 against 2.3.1

Measured 2026-10-17 on macOS 27.0.1, 1.5 s between switches. 2.3.1
is the release tag (`a35587d8c`); 3.0.0 is `e58659479` on its
release branch. 3.0.0 has no Space-switch animation and no Monocle
flip, so it is measured once and compared twice: against 2.3.1
with both of those off, and against 2.3.1 as it ships, with its
300 ms plate slide and the flip on.

Each cell reads **2.3.1 → 3.0.0**.

**2.3.1 with its switch animation and Monocle flip off**

| Pair | Load | AX calls | Parks | Retile mean | Retile max |
|---|---|---|---|---|---|
| bsp ↔ scrolling | idle | 152 → 166 | 10.4 → 9.9 | 10 → 10 | 40 → 36 |
| bsp ↔ scrolling | CPU | 153 → 164 | 10.1 → 10.1 | 8 → 8 | 26 → 32 |
| bsp ↔ scrolling | GPU | 154 → 166 | 10.9 → 10.9 | 8 → 10 | 45 → 173 |
| scrolling ↔ floating | idle | 185 → 185 | 7.9 → 7.8 | 10 → 11 | 36 → 48 |
| scrolling ↔ floating | CPU | 186 → 185 | 7.9 → 7.8 | 8 → 9 | 33 → 28 |
| scrolling ↔ floating | GPU | 186 → 186 | 9.0 → 8.8 | 16 → 20 | 289 → 229 |
| stack ↔ monocle | idle | 112 → 112 | 7.4 → 7.4 | 10 → 11 | 35 → 27 |
| stack ↔ monocle | CPU | 112 → 112 | 7.5 → 7.4 | 8 → 8 | 26 → 23 |
| stack ↔ monocle | GPU | 112 → 113 | 7.3 → 7.5 | 16 → 12 | 261 → 172 |

**2.3.1 as it ships**

| Pair | Load | AX calls | Parks | Retile mean | Retile max |
|---|---|---|---|---|---|
| bsp ↔ scrolling | idle | 159 → 166 | 10.2 → 9.9 | 9 → 10 | 30 → 36 |
| bsp ↔ scrolling | CPU | 159 → 164 | 9.9 → 10.1 | 8 → 8 | 28 → 32 |
| bsp ↔ scrolling | GPU | 158 → 166 | 10.0 → 10.9 | 12 → 10 | 300 → 173 |
| scrolling ↔ floating | idle | 182 → 185 | 8.2 → 7.8 | 10 → 11 | 36 → 48 |
| scrolling ↔ floating | CPU | 179 → 185 | 8.2 → 7.8 | 9 → 9 | 33 → 28 |
| scrolling ↔ floating | GPU | 181 → 186 | 8.8 → 8.8 | 38 → 20 | 376 → 229 |
| stack ↔ monocle | idle | 108 → 112 | 6.8 → 7.4 | 10 → 11 | 24 → 27 |
| stack ↔ monocle | CPU | 108 → 112 | 6.8 → 7.4 | 9 → 8 | 28 → 23 |
| stack ↔ monocle | GPU | 109 → 113 | 6.7 → 7.5 | 10 → 12 | 139 → 172 |

The two releases do the same work per switch: within a few
accessibility calls and parked windows on every pair, with
bsp ↔ scrolling up to 9 % more calls in 3.0.0, and the same
average layout pass. Those extra calls run off the main thread:
calls on it fall from about 50 to 40 per 20 switches, and their
time from 55 to 31 ms. Which change added them is not yet
attributed; it predates `2732a681d`. Against 2.3.1 as it ships, 3.0.0 is lighter
under a saturated GPU on the pair with floating windows, where
2.3.1's slide roughly doubled the average pass. The longest
passes under that load vary by tens of milliseconds between runs
of one build, so their differences are noise.

## Earlier comparisons

Each release's page keeps its own comparison; read it at that
release's tag:

- [2.2.0 against 2.1.1](https://github.com/KiwiCanopy/KiwiDesk/blob/v2.2.0/docs/performance.md#220-against-211)
