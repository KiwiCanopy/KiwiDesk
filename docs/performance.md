---
title: Performance
description: What a Space switch costs, release against release, measured on one fixed desk.
---

# Performance

What a Space switch costs KiwiDesk, measured the same way for
every release so the rows compare. Counts — accessibility calls,
windows parked — carry across machines; times are one machine's
and carry its noise, so compare them only within a table.

## How it is measured

- **The desk.** A fixed set of windows on one screen, one layout
  per Space: 3 TextEdit in bsp, 2 TextEdit and 2 VS Code in
  scrolling (two columns scrolled out), 2 Script Editor floating,
  3 in stack and 3 in monocle. The config is a Lua file every
  release reads, with every animation setting pinned.
- **The run.** Ten round trips between two Spaces (20 switches),
  each pair measured idle, with every core busy, and with the GPU
  held at 90 %+ by a WebGL shader. Each cell is the mean of two
  runs; a maximum is the median of the runs' maxima.
- **The machine.** Apple M1 Max, one screen, macOS 27.0.1.

The procedure and the desk script live in the repository's
`measure-work` skill.

## Columns

| Column | Meaning |
|---|---|
| AX calls | Accessibility calls to other apps per switch |
| Parks | Windows moved to or from the hiding corner per switch |
| Retile mean / max | Main-thread time of one layout pass, ms |
| Stalls | Window-animation frames late by more than the stall threshold, per run |

:::unreleased
## 2.2.0 against 2.1.1

Measured 2026-10-09. 2.1.1 is commit `126590ab`, its switching
code with the counters added. 2.2.0 animates a Space switch by
default (the plate slide, 550 ms); 2.1.1 does not, so both are
shown, and *slide off* is the like-for-like row.

**bsp ↔ scrolling (3 / 4 windows)**

| Release | Load | AX calls | Parks | Retile mean | Retile max | Stalls |
|---|---|---|---|---|---|---|
| 2.1.1 | idle | 385 | 38 | 42 | 88 | 7 |
| 2.2.0, slide off | idle | 131 | 11 | 10 | 37 | 0 |
| 2.2.0, default | idle | 125 | 10 | 6 | 18 | 0 |
| 2.1.1 | CPU | 385 | 38 | 33 | 62 | 10 |
| 2.2.0, slide off | CPU | 130 | 11 | 7 | 26 | 0 |
| 2.2.0, default | CPU | 124 | 10 | 6 | 22 | 0 |
| 2.1.1 | GPU | 412 | 42 | 45 | 279 | 9 |
| 2.2.0, slide off | GPU | 132 | 11 | 12 | 209 | 0 |
| 2.2.0, default | GPU | 125 | 11 | 24 | 266 | 0 |

**scrolling ↔ floating (4 / 2 windows)**

| Release | Load | AX calls | Parks | Retile mean | Retile max | Stalls |
|---|---|---|---|---|---|---|
| 2.1.1 | idle | 404 | 36 | 38 | 74 | 0 |
| 2.2.0, slide off | idle | 156 | 8 | 9 | 37 | 0 |
| 2.2.0, default | idle | 150 | 9 | 8 | 22 | 0 |
| 2.1.1 | CPU | 404 | 36 | 33 | 61 | 1 |
| 2.2.0, slide off | CPU | 155 | 8 | 8 | 29 | 0 |
| 2.2.0, default | CPU | 150 | 8 | 7 | 20 | 0 |
| 2.1.1 | GPU | 425 | 40 | 44 | 197 | 3 |
| 2.2.0, slide off | GPU | 155 | 9 | 14 | 129 | 0 |
| 2.2.0, default | GPU | 150 | 9 | 31 | 290 | 0 |

**stack ↔ monocle (3 / 3 windows)**

| Release | Load | AX calls | Parks | Retile mean | Retile max | Stalls |
|---|---|---|---|---|---|---|
| 2.1.1 | idle | 262 | 27 | 55 | 111 | 0 |
| 2.2.0, slide off | idle | 96 | 7 | 11 | 31 | 0 |
| 2.2.0, default | idle | 93 | 7 | 9 | 19 | 0 |
| 2.1.1 | CPU | 261 | 27 | 46 | 83 | 0 |
| 2.2.0, slide off | CPU | 96 | 8 | 8 | 18 | 0 |
| 2.2.0, default | CPU | 93 | 7 | 8 | 20 | 0 |
| 2.1.1 | GPU | 277 | 29 | 47 | 87 | 0 |
| 2.2.0, slide off | GPU | 96 | 8 | 9 | 21 | 0 |
| 2.2.0, default | GPU | 93 | 7 | 14 | 164 | 0 |

A switch in 2.2.0 makes about a third of the accessibility calls
and moves a quarter of the windows, and its average layout pass
is five to seven times shorter. Under a saturated GPU the slide
costs a longer worst pass than having it off: **Animate Space
switches** under **Looks & Animations ▸ Animations** turns it off.
:::
