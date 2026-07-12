---
title: User Guide
description: The Settings app, profiles, and the
  visual editor — everything without touching Lua.
---

# User Guide: The Settings App

This guide walks you through KiwiDesk's visual Settings window —
the point-and-click interface for all window tiling, monitors,
spaces, and keybindings. You never need to edit files directly
unless you want custom Lua.

## Getting Started

Open Settings from the KiwiDesk menu in the menu bar. The window
shows a two-group sidebar on the left:

- **Design** — sections scoped to the active profile (Spaces,
  Layout, Monitors, Appearance, Behavior).
- **System** — global settings that apply everywhere (Profiles,
  Shortcuts, App Rules, General).

At the top you'll see the app name and a banner showing which
profile is loaded and letting you edit a saved profile without
switching to it. At the bottom, a stable three-slot footer holds
Revert, Save a Copy As…, and Save.

### Permission & First Run

On first launch, a wizard prompts you to grant Accessibility
permission — KiwiDesk needs it to move and resize windows.
Follow the steps to enable it in System Settings › Privacy &
Security › Accessibility. Once granted, you may also be asked to
enable "Displays have separate Spaces" for proper multi-monitor
support — this is optional but recommended.

## How the App and init.lua Coexist

KiwiDesk keeps your custom Lua code in `~/.config/KiwiDesk/init.lua`
and never edits it. The Settings app stores its own configuration
in `~/.config/KiwiDesk/gui.json` (the global settings) and
individual profile JSON files (one per saved layout).

**Key points:**

- Saving in the Settings app never rewrites `init.lua`.
- Custom Lua (print statements, event hooks, anything that isn't
  app rules, float rules, keybindings, or profile bindings) lives
  safely alongside the visual editor.
- A small blue banner confirms "Custom Lua detected" when the
  app finds your own code.
- If you declare managed vocabulary (`app_rules`,
  `float_rules`, `KiwiDesk.bind`, keybinding definitions) *and*
  the Settings app tries to manage them, the app shows a raw Lua
  editor so you can resolve the conflict. You can then click
  **Adopt into the GUI** to import your settings, keeping your
  old file as a commented backup, or keep editing raw Lua.

Once `gui.json` exists, the visual editor owns tiling (gaps, modes,
layout tuning). Hand-written `set_gap_global` calls stop applying
on monitor changes — the built-in layout rules take over instead.
To persist custom tiling, save it as a profile in the Settings app.

## GUI Language

Go to **General** (in the **System** group) and pick a display
language. It covers the Settings window, the dashboard, and the
menu-bar quick menu. "System default" follows your macOS language
if KiwiDesk ships a translation, otherwise English. Your choice
applies instantly, touches no Lua or profile files, and persists
in app preferences only (`UserDefaults`, key `"language"`) — it
never flips the app to raw-editor mode. To add or fix a
translation, see [translating.md](translating.md).

## The gui.json File

The file `~/.config/KiwiDesk/gui.json` holds the app's complete
configuration. On a truly fresh install (no `init.lua` yet) it is
created at first launch, pre-filled with the
[default shortcuts](#default-shortcuts). On a hand-written setup
(an `init.lua` already exists) it is only created the first time
you Save in the Settings window. You normally never edit it by
hand, but it is documented here for backup and transparency.

**Top-level structure:**

```json
{
  "spaces": [ "1", "2", "mail" ],
  "app_rules": { "Spotify": "music" },
  "float_rules": [ "Calculator" ],
  "profile_bindings": { "1": "Developer" },
  "modes": [
    { "name": "default", "bindings": [...] }
  ]
}
```

Each field:

- **`spaces`**: array of space ids (strings). Defines the spaces
  you work with, in order. Updated whenever you add, rename, or
  delete a space in the Spaces section.
- **`app_rules`**: object mapping app names to space ids. When an
  app opens, its windows land in the assigned space. Updated in
  the App Rules section.
- **`float_rules`**: array of app names (and optionally
  app-name:title filters). Windows matching these never tile. Updated
  in the App Rules section.
- **`profile_bindings`**: object mapping native macOS Space numbers
  (Mission Control desktops) to profile names. When you switch
  desktops, the bound profile loads. Updated in the Profiles
  section.
- **`modes`**: array of keybinding modes. Each mode is an object with:
  - **`name`**: the mode name ("default" for the main set).
  - **`icon`**: optional SF Symbol name or emoji for the menu bar.
  - **`bindings`**: array of shortcut rows, each with:
    - **`combo`**: key combo string (e.g., `"cmd+alt+left"`).
    - **`lua`**: the Lua code to run (the body inside `function() ... end`).
    - **`kind`**: classification ("navigation", "application", or "custom").
    - **`label`**: display name for the row.

If you hand-edit the `modes` list, it is normalized on load:
modes with an empty name are dropped, a duplicated mode name
keeps only its first entry, the `default` mode always exists and
sits first, and an `icon` on the default mode is removed (its
menu bar indicator is fixed). The cleanup is silent; the next
Save persists the normalized list.

To reset the app to what your `init.lua` declares, delete `gui.json`.
Treat it like `init.lua` — do not import it from an untrusted source,
since custom Lua in keybindings runs on every reload.

## What Lives Where: Global vs Per-Profile

Your configuration is split across two homes, and knowing which is
which tells you the *blast radius* of any edit:

- **`gui.json` (global)** — one file, shared by every profile.
- **Each profile's JSON (per-profile)** — one file per saved
  profile, applied only while that profile is active.

**Global settings** live in `gui.json`; editing or deleting one
changes it for **every** profile:

- **Keyboard shortcuts** (the base set)
- **App rules** (app → space assignment)
- **Float rules** (apps that never tile)
- **Native Space → profile bindings**

**Per-profile settings** live in the profile's own JSON; editing
one touches **only that profile** — another profile that declares
a space of the same name is left untouched:

- **Which spaces exist** and their order (the list you see is the
  active profile's)
- **Layout mode, gaps, and per-layout / per-space tuning**
- **Space-to-monitor pins, the Main role, and the fallback space**

This is why, when you **edit a stored profile without switching to
it**, the App Rules and General sections disappear — they hold
global state a profile edit never writes.

**One hybrid — keyboard shortcuts.** The base set is global, but a
profile can carry a *sparse override* that adds, changes, or
removes specific bindings just for itself (see **Per-Profile
Shortcut Overrides**). Everything else is squarely one or the
other.

A practical consequence: because app rules are global, an app maps
to a single space name everywhere. To send an app to a given space
across profiles, give that space the **same name** in each profile
(e.g. keep a `comms` space and assign the app to it) — each profile
can still lay that space out differently.

## Spaces

The **Spaces** section (in the **Design** group) lists every virtual
workspace you manage. Each space is independent of monitors and can
span multiple displays or run on just one.

To **add a space**, click the **+** button and enter a name
(often a number like "1", "2", or a name like "web", "mail").

To **rename**, click the space name in the list.

To **delete**, right-click and pick Delete. The space is removed
right away — any windows in it move to the fallback space (or the
first space in the list when no fallback is set), and it stays gone
across reloads and restarts.

To **set a recognition icon** (optional), click the space name to
edit it and pick an SF Symbol, emoji, or single character. The icon
appears in the Monitors and Shortcuts sections as a visual aid.

To **mark a space as the fallback** for profile switches, right-click
a space and pick **Make Fallback**. When you load a profile, any
windows in spaces the new profile doesn't define are moved to this
fallback space instead of being hidden. Without an explicit choice,
windows land in the first space of the profile's list.

## Layout Defaults

The **Layout Defaults** section (in the **Design** group) controls
tiling for every space in this profile.

### Modes & Gaps

Pick a layout mode for each space:

- **BSP** (Binary Space Partition): recursive splits, every window
  gets a region.
- **Stack** (Master/Stack): one master zone and a collapsing stack.
- **Scrolling** (PaperWM style): columns or rows that scroll.
- **Monocle**: fullscreen focus, all windows hidden behind one.
- **Grid**: evenly-sized cells in rows and columns.
- **Track**: columns (or rows) of windows where every resize has
  one true target — grow *your* track, or *your* share within it
  (#128).
- **Floating**: every window floats freely, no tiling.

Set gaps with sliders (uniform gap, or per-edge: top, bottom, left,
right, plus inner gaps between windows). Gaps are carved out of the
layout — windows never overlap them. The app bar (if shown) also
carves its space from the layout.

### Per-Layout Tuning

Expand each layout type to adjust its defaults:

- **BSP**: split strategy (shortest_side or alternating) and the
  width and height split ratios (0.5 = 50/50 each) — the knobs
  the per-axis resize shortcuts nudge (#56).
- **Stack**: master count, master ratio (how much width/height the
  master zone takes), and overflow style (cascade_overflow keeps
  full windows, cascade_all cascades everything). The resize
  shortcuts are focus-aware (#67): width grows whichever zone
  holds the focused window, height grows the focused window's
  share of its column (a session-only tweak — it resets on
  relaunch and is not saved into profiles).
- **Scrolling**: orientation (horizontal or vertical), anchor
  (where a freshly revealed column comes to rest — center, left,
  right; once scrolled, the viewport pans minimally to keep the
  focus visible), slot size (auto, pixel count, or percentage of
  available space), and **Wrap focus** — off by default, so
  stepping focus past a row end stops there; turn it on to wrap
  from the last window back to the first (and vice versa). Swap
  never wraps.
- **Monocle**: orientation (affects which arrow keys cycle focus
  and where the app bar sits) and wrap focus. Monocle is a
  carousel, so wrap focus is **on** by default — cycling past the
  last window returns to the first; turn it off to stop at the
  ends.
- **Grid**: type (dynamic or rigid), fill empty space (yes/no),
  split direction (horizontal or vertical), and column and row
  counts. In dynamic mode the counts are an upper bound — the
  grid auto-balances up to that ceiling, then cascades the
  overflow in the last cell. **Auto-size grid** fits as many
  columns and rows as the screen allows at the minimum window
  size instead of the typed counts (greying them out), so a
  landscape monitor gets more columns than rows.
- **Track**: axis (vertical = columns side by side, horizontal =
  rows), track limit (0 = dynamic — tracks open and collapse as
  windows come and go), overflow style (when too many tracks or
  windows to hold the minimum size: `cascade_overflow` keeps the
  fitting ones tiled and cascades only the rest — the same
  choice as the stack layout — or `cascade_all`), where a new
  window lands (opens its own track next to the focused one, or
  joins the focused track), and **Wrap focus** — the same opt-in
  toggle as Scrolling's,
  off by default: on, focus wraps within the track along the
  axis and from the last track to the first across it. Swap
  never wraps. Track sizes and in-track shares are resize
  state, session-only like the stack's weights; bind
  `move_to_track` (Shortcuts ▸ Window Management) to move a
  window across tracks or open a new one at the edge.

> **A few resize behaviors are accepted limitations, not bugs.**
> Some tiling quirks — e.g. the inner window of a nested BSP pair
> not growing, or a stack window's *mouse* height-drag snapping
> back — are settled architectural trades, each with a reason and,
> where planned, a real fix. See
> [Accepted limitations](design-decisions.md#accepted-limitations).

### Per-Space Overrides

To tune the *same layout type differently in different spaces*, use
the per-space override toggles. For example, make space "3" scroll
vertically while every other scrolling space goes horizontal. Click
the space's override row and adjust just that field — unset fields
inherit the global value.

### App Bar

The app bar shows every window in the current space. Configure it
globally (applies to every layout that shows a bar) or override
individual fields per layout.

**Global settings:**

- **Style**: pills (floating rounded buttons), segments (a continuous
  strip), or underline (minimal text strip).
- **Position**: top, bottom, left, or right (layout orientation
  constrains valid edges).
- **Thickness**: the strip's depth in points.
- **Item size**: auto (0) or fixed pixel width.
- **Content**: icon only, name only, or both.
- **Colors**: text, box, active highlight, hover states, and group
  badge.
- **Font size**: auto (0) or fixed.
- **Corner radius**: rounding of pill/segment corners.

**Per-layout overrides:**

Click a layout to override one field just for that layout — e.g.,
make scrolling show segment style while monocle stays pills.

## Monitors

The **Monitors** section (in the **Design** group) pins spaces to
specific displays for this profile. It appears only when the profile's
monitor setup is connected; when editing a profile whose monitors
aren't connected, a read-only note appears instead.

**Drag space chips** onto monitor cards to pin a space to a display.
A pinned space always appears on that monitor when the profile loads.

**Drag onto the "Follows main display" card** to give a space the
**Main role**. That space moves with whatever display is currently
the Mac's main display (useful for your primary work space when you
dock/undock).

**Dimmed chips** are placed automatically by KiwiDesk — they are not
manually pinned but still show which spaces run on which monitors.

When you add a new monitor and save the profile, the new arrangement
is recorded so the profile becomes available for future loads with
this hardware.

## Appearance

The **Appearance** section (in the **Design** group) customizes
visual feedback.

### Drag Visuals

When you drag a tiled window, KiwiDesk shows two overlays:

- **Ghost** (the dragged window's slot) — where it snaps back if you
  release outside any other window.
- **Drop zone** (the slot under the cursor) — the window this drop
  would swap with.

Floating windows show neither overlay: they have no tile slot to
preview, and dropping one over a tiled slot does nothing. Use
*make tiled* to return a window to the grid first (see
[design decisions](design-decisions.md) for why).

Toggle each visual on/off and customize:

- **Border**: show/hide, color, thickness (pt), and alignment
  (inside or outside the slot edge).
- **Fill**: show/hide, color (with optional transparency).
- **Corner radius**: match your windows' corner rounding.

## Behavior

The **Behavior** section (in the **Design** group) adjusts timing and
interaction.

### Animations

- **Duration** (ms): how fast windows move and resize (50–1000, default
  250).
- **Scroll speed** (ms): scrolling-layout slide speed when focus moves
  (50–1000, default 250).
- **On space change**: animate when switching virtual spaces (default
  off; can be slow on older machines).
- **On scrolling**: animate the slide in scrolling layout (default on).
- **On window resize**: animate when splits adjust (default on).
- **On window swap**: animate when two tiles swap (default on).
- **On relayout**: animate when windows open/close or layout parameters
  change (default on).

### Mouse & Window Behavior

- **Mouse resize mode**: "layout" (default) — resize slides the split
  as you drag; "snap_back" — the layout snaps back when you release.
- **Minimum window size**: if a window shrinks below this (pt), it
  cascades instead of further shrinking (default 300 pt).
- **New window placement**: where new windows enter the space's window
  order — first, last, before focused, or after focused. Each layout
  has a sensible default; override per-space if needed.

### Wake & Restart

- **Restore on wake** (checkbox): when your Mac wakes from sleep,
  restore the previous window arrangement.
- **Wake restore delay** (ms): how long to wait after wake before
  restoring (default 1500 ms, giving apps time to settle).

When you quit or restart KiwiDesk, it saves window order and focus
per virtual space and restores on next launch. Windows land staggered
on the monitors they were assigned to, so every window is findable.

## Profiles

The **Profiles** section (in the **System** group) manages saved
layouts. Each profile captures tiling (modes, gaps, parameters),
space-to-monitor pins, and optionally a sparse keybinding override
layer.

### The Profile Banner

At the top of any section, a dropdown shows the currently active
profile (marked "currently loaded"). Click it to:

- **Switch to** a saved profile (loads it into the running layout).
- **Edit** a saved profile **without switching** — the Settings
  sidebar becomes profile-scoped: the Design sections (Spaces,
  Layout, Monitors, Appearance, Behavior) edit this profile, and
  **App Rules and General are hidden** — they hold global state a
  profile edit never writes. Save writes to this profile's JSON
  instead of the active one (the caption beside the button names
  the target). Shortcuts enters override mode and edits only the
  rows this profile changes; inherited rows stay dimmed.
- **Return to the active profile** by selecting it in the dropdown.

Saving a stored profile hot-reloads the running layout **only if
that profile is the one on screen** (loaded, or bound to the
active native Space); otherwise the change waits until the
profile next loads. **Save a Copy As…** while editing a stored
profile duplicates *that stored profile* — including your pending
edits, its monitor sets (even for hardware that isn't connected),
and its shortcut overrides. The count-default flag does not carry
over, and the running layout is never touched — this is how you
create a variant of a profile without loading it first.

### Saving

The footer always holds the same three slots, clustered at the
trailing edge — **Revert**, **Save a Copy As…**, and **Save**.
Only the primary **Save**'s label and target change with
context; there is no separate fourth button:

- **Revert** — discards pending edits and reloads the target's
  stored state.
- **Save a Copy As…** — creates a new profile from the current
  state. The new profile covers only the connected monitors.
  Names are suffixed `_1`, `_2`, … when taken.
- **Save** — persists edits to the current target. When an
  active profile exists it writes to that profile and
  adds/refreshes the connected monitor set; it is greyed out if
  the connected screen count differs from the profile's count
  ("this profile is for 2 screens"). When you are on a transient
  layout or a built-in Standard, the same slot instead reads
  **Save as New Profile…** and creates a real profile from
  scratch. The banner's profile picker names the edit target
  authoritatively.

After saving, if a global setting changed (keybindings, app/float
rules, or native Space bindings), `gui.json` is rewritten. Tiling-only
edits touch only the profile JSON. `init.lua` is never written.

Neither live save carries a keybinding override: the live
Shortcuts section edits the *base* shortcuts, so both live saves
capture tiling only. To give a profile its own shortcuts, pick it
in the banner dropdown and edit its Shortcuts section in override
mode (see [Per-Profile Shortcut Overrides](#per-profile-shortcut-overrides)).

### Built-in Standards & Presets

KiwiDesk ships seven built-in **profiles** — Standards for 1, 2, or
3 screens that resolve silently when no saved profile matches, and
Presets you can apply to spin up a starting point. (These are whole
profiles — not to be confused with the six layout *modes* like bsp
or stack.)

**1 Screen:**

- **Developer** *(Standard)* — IDE in stack (space 2), docs in scrolling
  (space 3), preview fullscreen (space 4). Best for software dev.
- **Minimalist** — Spacious gaps (20 pt), scrolling reading (space 1),
  monocle focus (space 3), floating scratch (space 4). Distraction-free
  work.
- **Focus Stack** — Two stacked task spaces (1–2), deep-work monocle
  (space 4). Heavy multitasking.

**2 Screens:**

- **Dual Developer** *(Standard)* — Main screen: IDE/docs/preview.
  Secondary: mail/chat/media. Tight gaps (8 pt).
- **Coder & Monitor** — Main screen: editor/terminals. Secondary:
  dashboards and logs. More stack space.

**3 Screens:**

- **Command Center** *(Standard)* — Left: communication (stack).
  Center: workspace (IDE/docs/preview). Right: logs/monitoring.
- **Visual Creative & Developer** — Left: design canvas. Center:
  frontend IDE. Right: inspectors. Mixed layouts for creative
  workflows.

To apply a preset, go to the **Presets** section (in the **System**
group). Click **Apply** next to the preset whose screen count matches
your connected displays. The layout loads and is saved as an editable
profile under the preset's name. The first profile saved for a screen
count becomes that count's default.

Presets themselves cannot be deleted; they always stay available. If
you delete all saved profiles for a screen count, that count silently
reverts to its Standard on the next monitor change.

## App Rules

The **App Rules** section (in the **System** group) controls where
windows of specific apps land and whether they tile.

### App Launch Assignment

Click **+** to add a rule. Enter an app name (e.g., "Spotify", "Mail")
and pick a space — new windows of that app will open in the chosen
space.

Click an app row to edit it, or right-click to delete.

To **match only certain windows** of an app (not all), use the format
`"App:Title fragment"` — e.g., "Finder:Get Info" floats only the Get
Info dialog, not all Finder windows.

### Float Rules

In the same section, add float rules to make windows never tile —
they always float. Use the same format: app name, or `"App:Title"` for
a title substring match.

Dialogs, sheets, and picture-in-picture windows float automatically —
you do not need a rule for them.

## Shortcuts

The **Shortcuts** section (in the **System** group) binds keyboard
combos to actions. Every shortcut lives in a **mode** — normally the
**default** mode (active at startup), plus optional modal modes
(vim-style); only the active mode's bindings fire at a time.

### Default Shortcuts

A fresh install starts with a usable set in the default mode, so
you can drive KiwiDesk before configuring anything:

| Action | Shortcut |
| --- | --- |
| Focus window left / down / up / right | `⌥H` `⌥J` `⌥K` `⌥L` |
| Go to space 1–9 | `⌥1` … `⌥9` |
| Swap with window left / down / up / right | `⌥⇧H` `⌥⇧J` `⌥⇧K` `⌥⇧L` |
| Move to space 1–9 | `⌥⇧1` … `⌥⇧9` |
| Shrink / Grow width | `⌥-` / `⌥=` |
| Shrink / Grow height | `⌥⇧-` / `⌥⇧=` |
| Make floating | `⌥T` |

The digits are display-order positions: `⌥3` targets the *third*
space in your Spaces list, whatever its name. A row is generated
only for spaces that exist when the set is seeded (at most nine),
so no shortcut ever targets a space that isn't there.

The set is seeded only while **no** shortcut is bound anywhere —
into `gui.json` at first launch on a fresh install, or into the
editable model when your `init.lua` declares no keybindings. It
never overwrites bindings you (or your Lua) authored, and every
seeded row is an ordinary catalog row: rebind, clear, or override
it per profile like any other shortcut.

### Recording a Shortcut

Click an empty row or the **Edit** pencil on an existing row. Click
**Record** and press your key combo. The recorder:

- **Locks on full release** — captures modifiers and one key, commits
  when everything is released.
- **Shows live preview** as you form the combo.
- **Lets you correct mid-chord** — release a key and press another to
  change it.
- **Cancels** on Escape, click-away, or app switch.

The shortcut displays as compact macOS glyphs (⌃⌥⇧⌘ for modifiers,
then the key), mapped to your active keyboard layout. No `+`
separator — a literal `+` key shows as `⌘+`. The stored config keeps
long word forms (`cmd`, `alt`, `semicolon`, …).

### Conflict Detection

A ⚠️ icon appears next to any row whose combo:

- Duplicates another row in the same mode.
- Conflicts with a reserved macOS shortcut.

Hover the icon for a tooltip naming the conflict. This indicator
updates live — no action needed to see it.

When a conflict is introduced (by recording a clashing shortcut,
adopting a hand-written config, or saving from the raw Lua
editor), a dismissible banner appears naming every current
conflict. With exactly one:

```
Shortcut for "Close" is conflicting with the macOS
shortcut "Close Window".
```

With more than one, a bulleted summary lists each pair. The
banner clears itself once the last conflict is fixed (or can be
dismissed early). It does **not** appear on app launch, when
Settings is simply opened, on Load Profile, or on a normal
visual-editor Save — those already show any conflict through the
persistent ⚠️.

### Keyboard Modifiers & Keys

**Modifiers**: `cmd`/`command`, `alt`/`opt`/`option`,
`ctrl`/`control`, `shift`.

**Keys**: letters (a–z), digits (0–9), arrows, `home`, `end`,
`pageup`, `pagedown`, `space`, `return`, `tab`, `escape`,
`f1`–`f12`, and punctuation. Punctuation can be entered as the
symbol or a word name:
- `;` or `semicolon`
- `,` or `comma`
- `.` or `period`
- `/` or `slash`
- `\` or `backslash`
- `-` or `minus`
- `=` or `equal`
- `[` or `leftbracket`
- `]` or `rightbracket`
- `` ` `` or `grave` / `backtick`
- `'` or `quote` / `apostrophe`

A combo is one set of modifiers + exactly one key. Multi-key chords
like `cmd+j+k` are not supported — use modal modes instead.

### Actions

Each row has an action. Built-in actions live under headings:

- **Focus** — move focus (left, right, up, down).
- **Move Windows** — swap windows, send to space, resize.
- **Applications** — open or focus an app.
- **Custom Bindings** — custom Lua (from Adopt/Import or hand-written).

When you save, every shortcut lives in a mode in `gui.json`. To use
an action not in the built-in sections, write custom Lua in a row
under Custom Bindings.

### Inactive Shortcuts

The per-space rows above render one row per space in the current
space list. A bound shortcut whose target space is *not* in that
list — say `⌥6 → Go to Space 6` after switching from an 8-space
to a 4-space profile — appears in a dimmed **Inactive shortcuts**
section at the bottom instead of disappearing. Such a shortcut:

- **Still works** — pressing it recreates its space and switches
  to it.
- **Still holds its combo** — recording the same combo elsewhere
  is blocked, with *Steal* and *Go to* pointing at the inactive
  row.
- **Is never deleted for you** — it becomes a normal row again
  the moment its space returns (e.g. switching back to the
  profile that declares it). Rebind or clear it in the section
  if you want the combo back now.

### Import & Adopt

If your `init.lua` holds custom keybindings:

- **Import from init.lua…** (shown in the Shortcuts header when custom
  Lua is present) reads shortcuts from your file, lets you review
  them, and adds them before you Save. Each binding must be an inline
  `function() … end` on one line for the import to recognize it.
- **Adopt into the GUI** (shown when managed vocabulary conflicts are
  detected) imports your entire `init.lua` settings into the app,
  keeps your file as a commented backup, and drops the raw Lua editor.

### Modal Modes

In the **Shortcuts** header, click **+ Mode** to define a vim-style
mode — a mode where only its bindings fire. Each mode has a name
(e.g., "resize"), an optional menu bar icon (SF Symbol or emoji), and
a set of bindings that shadow the base shortcuts when the mode is
active. Use `KiwiDesk.switch_mode` to switch modes (see
[lua-reference.md](lua-reference.md)).

### Per-Profile Shortcut Overrides

When editing a stored profile (via the banner dropdown), the Shortcuts
section enters **override mode**:

- **Dimmed rows** are inherited from the base config (live shortcuts).
- **Edit a row** to override it for this profile only — it turns bold.
- **Delete an override row** to reset it back to inherited.

Only the rows this profile changes are stored in its JSON. Every base
binding the profile does not override stays active — your profile-switch
shortcut can never be lost by omission.

## Native Spaces (Mission Control)

The **Profiles** section in the **System** group has a **Native Spaces**
subsection listing each macOS desktop (Mission Control number). Assign
a profile to each desktop using the dropdown.

When you switch desktops (Ctrl+arrow, Mission Control, …), the bound
profile loads with its spaces, layouts, and settings. Desktops without
a binding keep whatever profile is active.

Bindings edited here are stored in `gui.json`
(`profile_bindings`); a hand-written config declares them in
`init.lua` with `bind_profile_to_native_space` instead. Each
desktop also remembers which virtual space it was on — return to
it and you land on the same space.

## Getting Help

For a complete reference on Lua configuration, see
[lua-reference.md](lua-reference.md). For integration recipes
(sketchybar, external commands, …), see [recipes](recipes/index.md).
For the CLI, see [cli.md](cli.md).

To check your current state in raw form, run:
```
KiwiDesk get_state
KiwiDesk get_profile_status
```

To reload your config after editing `init.lua` by hand:
```
KiwiDesk reload_config
```

## Troubleshooting

**Accessibility permission missing?**  
Go to System Settings › Privacy & Security › Accessibility and add
KiwiDesk. It will prompt you when needed.

**Settings window won't open?**  
Restart KiwiDesk via menu bar › Service › Restart, or run
`KiwiDesk service restart` in a terminal.

**Shortcut not working?**  
Check the Shortcuts section for a ⚠️ conflict marker. Verify the combo
is not reserved by macOS. If you hand-edited, reload with
`KiwiDesk reload_config`.

**Typo in init.lua?**  
A misspelled function name (e.g. `scroll.set_width` instead of
`scroll.set_slot_size`) doesn't abort the config: the call is
skipped with a did-you-mean hint and the rest of the file still
runs. Every typo the load hits is listed under menu bar › Config
Issues… — if the error badge is showing, check there first.

**Windows aren't tiling?**  
Ensure the space has a layout mode other than Floating set in Layout
Defaults. Check that the app is not in float_rules. If using a
hand-written config, make sure `init.lua` exists and the app is
managing tiling (check the banner).

**Profile not loading after monitor change?**  
Profiles are matched to specific monitor sets. A new hardware
combination uses the built-in Standard and marks the profile dirty
until you Save. To pin the profile to new hardware, edit it and Save
on this monitor setup.
