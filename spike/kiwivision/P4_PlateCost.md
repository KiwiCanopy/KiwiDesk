# P4 — what does a persistent full-screen backdrop blur cost?

Decides whether KiwiVision's blur may be **on by default** (#2103
v0). The plate is held by `P4_PlateHolder`, a separate process, so
this measures the COMPOSITOR's cost of a standing blur under the
focused window — GPU utilisation, GPU power, WindowServer CPU, and
what that load does to KiwiDesk's own Space switches. The main-thread
cost of KiwiDesk ordering the plate itself is P2's and P7's number,
not this one.

Needs: the owner's desk, the gate slot (a bundle build), `sudo` for
`powermetrics`, and ~45 minutes with hands off. Run it LAST: it swaps
the running KiwiDesk, and a GPU sitting heats the machine for whatever
comes next.

## 0. Build

```bash
S=<scratch>/kv-p4; mkdir -p "$S"
cd spike/kiwivision
swiftc -O -parse-as-library Harness.swift HarnessPlates.swift \
    HarnessPixels.swift P4_PlateHolder.swift -o "$S/p4-holder" \
    -framework AppKit
cd ../..
scripts/build-app.sh --output "$S/app"     # takes the gate slot
```

## 1. Swap in and pick the pair

```bash
MW=.claude/skills/measure-work/scripts
$MW/swap-instance.sh start "$S/app/KiwiDesk.app" "$S/swap.state"
"$S/app/KiwiDesk.app/Contents/MacOS/KiwiDesk" get_state > "$S/state.json"
```

Pick two Spaces on the SAME screen that both hold windows (measure-work
§3) and record the window count of each.

## 2. Standing cost, no switching (30 s each)

For each condition — `off`, `--kind dim`, `--kind hud`, `--kind glass`
(macOS 26+) — with the focused window a plain TextEdit document:

```bash
mkdir -p "$S/standing-hud"
"$S/p4-holder" "$S/standing-hud" --kind hud --dim 0.3 &   # skip for "off"
sleep 5
for i in $(seq 30); do
  ioreg -r -d 1 -c IOAccelerator | grep -o '"Device Utilization %"=[0-9]*'
  sleep 1
done > "$S/standing-hud/gpu.txt"
sudo powermetrics --samplers gpu_power -i 1000 -n 30 > "$S/standing-hud/power.txt"
top -l 30 -s 1 -stats pid,command,cpu | grep WindowServer > "$S/standing-hud/ws.txt"
kill -INT %1                                               # orders the plates out
```

Order the conditions off, dim, hud, glass, glass, hud, dim, off (A-B-A,
measure-work §6: a later sitting pays for a warmer machine).

## 3. Switch cost with the plate standing

Per measure-work §3, for each of `off` and `--kind hud` (and `glass`
on macOS 26+), idle and `--gpu-load`, two runs each:

```bash
S2=$MW/measure-switches.sh; APP="$S/app/KiwiDesk.app"; mkdir -p "$S/switch-hud"
"$S/p4-holder" "$S/switch-hud" --kind hud &    # skip for "off"
$S2 "$APP" <a> <b> 10            > "$S/switch-hud/idle-1.json"
$S2 "$APP" <a> <b> 10 --gpu-load > "$S/switch-hud/gpu-1.json"
kill -INT %1
```

The holder re-orders on every activation, so the plate follows the
switches; its `p4-holder.csv` records each order's time.

## 4. Put the desk back

```bash
$MW/swap-instance.sh restore "$S/swap.state"
```

Always, including after a failed step.

## 5. Read

- Standing: GPU Device Utilization mean and `GPU Power` mean, off vs
  each kind; WindowServer CPU mean.
- Switching: `retile_ms_mean`/`max`, `queue_wait_ms_max`,
  `bar_renders_per_switch`, and any `frame clock stalled` lines, off vs
  on, per load. A pair disagreeing by more than a quarter is noise —
  take a third run.

**Proposed bar for blur default-on (the owner rules it):** idle, the
blur adds ≤ 5 points of Device Utilization and ≤ 10 % GPU power over
the dim-only plate; under GPU load, no switch counter moves beyond the
pair noise and no new stall appears. A blur that misses ships OFF by
default with the dim alone on.
