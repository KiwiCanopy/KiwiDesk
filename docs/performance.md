---
title: Performance
description: What a Space switch costs, release against release, measured on one fixed desk.
---

# Performance

What a Space switch costs KiwiDesk, measured the same way for
every release so the rows compare. Counts — accessibility calls,
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

:::unreleased
## 2.2.0 against 2.1.1

Measured 2026-10-09 on macOS 27.0.1, 1.5 s between switches so
every animation finishes. 2.1.1 is commit `126590ab`, its
switching code with the counters added. Each release is measured
with every animation off, and with its Space-switch animation on
at the same 300 ms: 2.1.1 slides the windows themselves, paced by
its shared window duration, so its window animations also run at
300 ms there; 2.2.0 plays the plate slide, its default.

Each cell reads **2.1.1 → 2.2.0**. bsp ↔ scrolling and
scrolling ↔ floating carry the VS Code windows; stack ↔ monocle
holds native apps only.

**All animations off**

| Pair | Load | AX calls | Parks | Retile mean | Retile max |
|---|---|---|---|---|---|
| bsp ↔ scrolling | idle | 397 → 131 | 38 → 11 | 31 → 7 | 71 → 20 |
| bsp ↔ scrolling | CPU | 397 → 131 | 38 → 11 | 26 → 6 | 56 → 16 |
| bsp ↔ scrolling | GPU | 418 → 131 | 42 → 11 | 24 → 6 | 50 → 14 |
| scrolling ↔ floating | idle | 414 → 155 | 36 → 8 | 28 → 7 | 65 → 17 |
| scrolling ↔ floating | CPU | 414 → 156 | 36 → 8 | 25 → 6 | 56 → 20 |
| scrolling ↔ floating | GPU | 435 → 157 | 40 → 8 | 32 → 7 | 200 → 122 |
| stack ↔ monocle | idle | 262 → 96 | 26 → 8 | 41 → 7 | 94 → 19 |
| stack ↔ monocle | CPU | 262 → 96 | 26 → 8 | 36 → 6 | 70 → 13 |
| stack ↔ monocle | GPU | 277 → 97 | 29 → 7 | 35 → 7 | 81 → 13 |

**Space-switch animation on, 300 ms**

| Pair | Load | AX calls | Retile mean | Retile max |
|---|---|---|---|---|
| bsp ↔ scrolling | idle | 727 → 125 | 38 → 9 | 94 → 30 |
| bsp ↔ scrolling | CPU | 730 → 124 | 32 → 7 | 64 → 29 |
| bsp ↔ scrolling | GPU | 705 → 124 | 35 → 5 | 155 → 16 |
| scrolling ↔ floating | idle | 637 → 151 | 36 → 9 | 76 → 35 |
| scrolling ↔ floating | CPU | 631 → 150 | 33 → 8 | 67 → 30 |
| scrolling ↔ floating | GPU | 618 → 150 | 81 → 15 | 632 → 195 |
| stack ↔ monocle | idle | 655 → 92 | 43 → 9 | 103 → 21 |
| stack ↔ monocle | CPU | 662 → 93 | 39 → 8 | 81 → 20 |
| stack ↔ monocle | GPU | 658 → 93 | 44 → 7 | 84 → 18 |

Parks are left out of the second table: with its animation on,
2.1.1 slides windows to the corner instead of parking them, so
the count measures something else.

A switch in 2.2.0 makes about a third of the accessibility calls
2.1.1 made and moves a quarter of the windows, and its average
layout pass is four to six times shorter with animations off.
With the switch animation on, 2.2.0's slide costs a few ms over
having it off; 2.1.1's slide added most of its own AX calls and,
under a saturated GPU, its longest passes.
:::
