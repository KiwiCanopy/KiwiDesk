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

**bsp ↔ scrolling (3 / 4 windows, 2 of them VS Code)**

| Release | Animations | Load | AX calls | Parks | Retile mean | Retile max |
|---|---|---|---|---|---|---|
| 2.1.1 | off | idle | 397 | 38 | 31 | 71 |
| 2.2.0 | off | idle | 131 | 11 | 7 | 20 |
| 2.1.1 | on | idle | 727 | 12 | 38 | 94 |
| 2.2.0 | on | idle | 125 | 10 | 9 | 30 |
| 2.1.1 | off | CPU | 397 | 38 | 26 | 56 |
| 2.2.0 | off | CPU | 131 | 11 | 6 | 16 |
| 2.1.1 | on | CPU | 730 | 12 | 32 | 64 |
| 2.2.0 | on | CPU | 124 | 10 | 7 | 29 |
| 2.1.1 | off | GPU | 418 | 42 | 24 | 50 |
| 2.2.0 | off | GPU | 131 | 11 | 6 | 14 |
| 2.1.1 | on | GPU | 705 | 12 | 35 | 155 |
| 2.2.0 | on | GPU | 124 | 11 | 5 | 16 |

**scrolling ↔ floating (4 / 2 windows, 2 of them VS Code)**

| Release | Animations | Load | AX calls | Parks | Retile mean | Retile max |
|---|---|---|---|---|---|---|
| 2.1.1 | off | idle | 414 | 36 | 28 | 65 |
| 2.2.0 | off | idle | 155 | 8 | 7 | 17 |
| 2.1.1 | on | idle | 637 | 15 | 36 | 76 |
| 2.2.0 | on | idle | 151 | 8 | 9 | 35 |
| 2.1.1 | off | CPU | 414 | 36 | 25 | 56 |
| 2.2.0 | off | CPU | 156 | 8 | 6 | 20 |
| 2.1.1 | on | CPU | 631 | 15 | 33 | 67 |
| 2.2.0 | on | CPU | 150 | 8 | 8 | 30 |
| 2.1.1 | off | GPU | 435 | 40 | 32 | 200 |
| 2.2.0 | off | GPU | 157 | 8 | 7 | 122 |
| 2.1.1 | on | GPU | 618 | 16 | 81 | 632 |
| 2.2.0 | on | GPU | 150 | 9 | 15 | 195 |

**stack ↔ monocle (3 / 3 windows, native apps only)**

| Release | Animations | Load | AX calls | Parks | Retile mean | Retile max |
|---|---|---|---|---|---|---|
| 2.1.1 | off | idle | 262 | 26 | 41 | 94 |
| 2.2.0 | off | idle | 96 | 8 | 7 | 19 |
| 2.1.1 | on | idle | 655 | 19 | 43 | 103 |
| 2.2.0 | on | idle | 92 | 7 | 9 | 21 |
| 2.1.1 | off | CPU | 262 | 26 | 36 | 70 |
| 2.2.0 | off | CPU | 96 | 8 | 6 | 13 |
| 2.1.1 | on | CPU | 662 | 19 | 39 | 81 |
| 2.2.0 | on | CPU | 93 | 7 | 8 | 20 |
| 2.1.1 | off | GPU | 277 | 29 | 35 | 81 |
| 2.2.0 | off | GPU | 97 | 7 | 7 | 13 |
| 2.1.1 | on | GPU | 658 | 20 | 44 | 84 |
| 2.2.0 | on | GPU | 93 | 7 | 7 | 18 |

A switch in 2.2.0 makes about a third of the accessibility calls
2.1.1 made and moves a quarter of the windows, and its average
layout pass is four to six times shorter with animations off.
With the switch animation on, 2.2.0's slide costs a few ms over
having it off; 2.1.1's slide added most of its own AX calls and,
under a saturated GPU, its longest passes.
:::
