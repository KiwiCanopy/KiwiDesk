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
average layout pass. Against 2.3.1 as it ships, 3.0.0 is lighter
under a saturated GPU on the pair with floating windows, where
2.3.1's slide roughly doubled the average pass. The longest
passes under that load vary by tens of milliseconds between runs
of one build, so their differences are noise.
:::

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
