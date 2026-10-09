# KiwiVision v0 — device probes (#2103)

A spike on `spike/kiwivision-probes`; it never merges. Each probe answers
one v0 question from #2103 with numbers, prints its pass bar, and runs a
negative control that must FAIL, so a pass means something. Nothing here
has been compiled or run yet: the first build is the owner's, at the desk.
Every API guess is marked `// UNVERIFIED:` in the source.

| Probe | Question | Decides |
|---|---|---|
| P2 `P2_OrderBelowForeign.swift` | Does `.below` a foreign window read back, plate below the ring? | everything else |
| P1 `P1_MidStackBlur.swift` | Does a behind-window blur render mid-stack? Is there a continuous blur axis? | blur at all; a "blur level" control |
| P3 `P3_GlassHaze.swift` | Glass as a haze: refraction at the edges, or uniform? | the material |
| P7 `P7_PerFloatCost.swift` | Cost of one extra order per float per focus change | floats in v1 or v2 (ruling 3) |
| P5 `P5_Appearance.swift` | System appearance through SkyLight, no prompt? | ruling 7's mechanism |
| P6 `P6_RaiseWithoutActivate.swift` | Raise several apps' windows above the plate without activating them? | v3 app sets |
| P4 `P4_PlateCost.md` + `P4_PlateHolder.swift` | GPU cost of a standing full-screen blur | blur on by default |

## Order: P2, P1, P3, P7, P5, P6, P4

P2 first: if the plate cannot be ordered under a foreign window and read
back, P1, P3 and P7 measure nothing. P1 before P3 (P3 only matters if the
blur renders). P7 reuses P2's loop. P5 and P6 are independent and need
their own permissions. P4 last: it swaps the running KiwiDesk, takes the
gate slot and heats the GPU.

## Before you run (P1–P3, P5–P7)

- **Quit KiwiDesk** (by its own path, never a generic `pkill`). It tiles
  the probes' windows, and its own ring orders below the focused window,
  which would sit between target and ring stand-in and fail P2's +1/+2
  read-back for a reason that is not the probe's.
- One Desktop, Reduce transparency OFF, no other window-overlay tools
  (HazeOver, borders apps) running.
- Open **TextEdit** with one document window filled with text (P1 needs
  detail in it), **Preview** with one document, and run from
  **Terminal.app**.
- Leave the desk alone while a probe runs; each prints `PASS`/`FAIL`/`INFO`
  lines and appends them to `<out>/summary.txt`.

## Build

From `spike/kiwivision/`, with `S` a scratch directory (never the worktree):

```bash
H="Harness.swift HarnessPlates.swift HarnessPixels.swift"
F="-framework AppKit -framework ApplicationServices -framework ImageIO \
   -framework UniformTypeIdentifiers"
swiftc -O -parse-as-library $H P2_OrderBelowForeign.swift   -o "$S/p2" $F
swiftc -O -parse-as-library $H P1_MidStackBlur.swift        -o "$S/p1" $F
swiftc -O -parse-as-library $H P3_GlassHaze.swift           -o "$S/p3" $F
swiftc -O -parse-as-library $H P7_PerFloatCost.swift        -o "$S/p7" $F
swiftc -O -parse-as-library $H P5_Appearance.swift          -o "$S/p5" $F
swiftc -O -parse-as-library $H P6_RaiseWithoutActivate.swift -o "$S/p6" $F
swiftc -O -parse-as-library $H P4_PlateHolder.swift         -o "$S/p4-holder" $F
```

`-parse-as-library` is required: every probe declares its own `@main`.
Plain `swiftc`, not `swift build`, so the gate hook does not apply and no
gate slot is taken — but a compile is still CPU load, so build everything
before any measuring run.

## Run

The first argument is the output directory; flags follow.

```bash
"$S/p2" "$S/out-p2"                    # --iterations 200 --skylight-neg 20
"$S/p1" "$S/out-p1"                    # --settle 0.4
"$S/p3" "$S/out-p3"                    # then open out-p3/p3/index.html
"$S/p7" "$S/out-p7-idle"               # --iterations 100 --ks 0,1,3,6
"$S/p7" "$S/out-p7-gpu"                # under the GPU page, below
"$S/p5" "$S/out-p5"                    # SkyLight; --system-events for the fallback
"$S/p6" "$S/out-p6"                    # --runs 20
```

P4 is a procedure: follow `P4_PlateCost.md`.

**P7 under GPU load** (the measure-work skill's page; #1925's stall only
showed under it):

```bash
MW=../../.claude/skills/measure-work/scripts
python3 -m http.server 8765 --bind 127.0.0.1 --directory "$MW" >/dev/null 2>&1 &
caffeinate -d &
open -a Safari http://127.0.0.1:8765/gpu-load.html
# wait until this reads >= 90, then run p7; P7 prints it at start and end too
ioreg -r -d 1 -c IOAccelerator | grep -o '"Device Utilization %"=[0-9]*'
# afterwards: close the tab, then
kill %1 %2
```

A reading whose start or end utilisation is under 90 does not count.

**P5** — in a second terminal before running it:

```bash
/usr/bin/log stream --predicate 'subsystem == "com.apple.TCC"' --style compact
```

No TCC line and no prompt on screen during the SkyLight run is the
pass. P5 restores the starting appearance, Auto included, on exit and on
Ctrl-C/SIGTERM/SIGHUP. A SIGKILL or a crash cannot: put it back in
System Settings ▸ Appearance by hand, and check `defaults read -g
AppleInterfaceStyle` / `AppleInterfaceStyleSwitchesAutomatically`
against `out-p5/summary.txt`'s `start` line.

## Permissions (all on the HOST terminal app)

| Probe | Needs |
|---|---|
| P1, P3 | Screen Recording (captures). Without it the capture shows wallpaper only; P1 refuses on a detail-less B region. |
| P5 | Screen Recording for the menu-bar luminance (optional); `--system-events` asks Automation for System Events once. |
| P6 | Accessibility (AXRaise). |
| P2, P7 | None. |
| P4 | `sudo` for `powermetrics`; KiwiDesk's own Accessibility grant on the scratch bundle (measure-work). |

## What needs the owner

| Probe | Hands | Eyes | sudo | Gate slot |
|---|---|---|---|---|
| P2 | setup only | — | — | — |
| P1 | setup only | glance that A really blurs | — | — |
| P3 | setup only | **contact sheet** is the verdict's other half | — | — |
| P7 | GPU page | — | — | — |
| P5 | — | **watch for a prompt** | — | — |
| P6 | setup only | — | — | — |
| P4 | swap, pair pick | — | **yes** | **yes** (bundle build) |

## v0 report template

Fill one per sitting; paste raw numbers, not adjectives.

```
KiwiVision v0 — <date>, macOS <sw_vers -productVersion> (<build>), <machine>
Desk: screens <n>, KiwiDesk <quit | version for P4>

P2 order .below foreign + below ring
  read-back        <ok>/<attempts> at +1/+2 within 100 ms   (bar 200/200)
  latency          p50 <> ms  p99 <> ms
  order call       p99 <> ms  max <> ms                     (bar < 5 ms idle)
  NEG start-front  <n>/<n> started in front
  NEG SkyLight     applied <n>/20 (expected 0, #1962) | symbol absent

P1 mid-stack blur
  verdict          hud .active: A <>% (≤20)  B <>% (98–102)   PASS/FAIL
  .followsWindowActiveState  A <>%   glass clear/regular  A <>% / <>%
  continuous axis  yes/no — which sweep(s): <name: steps, drift>
                   (decides a "blur level" control; glass fade = tint bare?)
  NEG magenta      A <rgb>  B <>%      NEG front blur  B <>% (≤50)

P3 haze
  recommended material  <> — contact sheet <path or attached>
  per variant      worst edge deviation <>%  inner displacement <> px
  NEG no plate     <ratios 1.0, displacement 0>

P7 per-float cost
  idle             k=0/1/3/6 added p99 <> / <> / <> / <> ms
  GPU ≥90 %        k=0/1/3/6 added p99 <> / <> / <> / <> ms; worst call <> ms
  stalls ≥300 ms   <n>                      => floats v1 | v2
  NEG moved above  <n>/<n>

P5 appearance
  mechanism        SLSSetAppearanceThemeLegacy present/absent; Notifying present/absent
  flip             defaults <> ms  fresh window <> ms  notification <> ms
  prompt           none | <what appeared>   TCC log: <lines>
  restore exact    yes/no (Auto: <start> -> <end>)
  NEG same / bogus <unchanged> / <nil>

P6 raise without activation
  result           <n>/20 above plate, no activation, host kept key
  NEG buried       <n>/20    NEG activate caught  yes/no
  (feeds v3)

P4 plate cost
  standing idle    GPU util off/dim/hud/glass <>/<>/<>/<> %; power <>/<> mW;
                   WindowServer CPU <> %
  switch           retile_ms_mean off/on <>/<> (idle), <>/<> (GPU); stalls <>
  => blur default-on yes/no

Device facts (each scoped to this date and build)
  for borders.md:        <e.g. ".below a foreign window reads back at +1 in <n> ms">
  for os-private-apis.md: <e.g. "SLSSetAppearanceThemeLegacy present, flips
                          without a prompt, macOS <> (<build>), observed <date>">
```

## Files

- `Harness.swift` — args, CSV, run-loop pumping, timing, `stack()`,
  `frontWindow(ofPID:)`, coordinate flip, `skyLightSymbol` (dlsym only).
- `HarnessPlates.swift` — `makePlate`/`configure` (dim, visual effect,
  glass, solid; the ring's panel recipe), the ring stand-in, activation
  with a LaunchServices fallback, `gpuBusy()`.
- `HarnessPixels.swift` — `capture(rect:)` via `screencapture -x -R`,
  `edgeEnergy` (Laplacian variance), `meanRGB`, PNG output, target windows
  (checkerboard + text, 1-pt line grid, gradient).
