---
paths:
  - "Sources/KiwiDesk/**"
---

# Settings app & SwiftUI GUI

Canonical for this subsystem (AGENTS.md §2.7 and §5 index it).

## North star — simplicity, intuitiveness, Apple-native, in that order

The Settings app should feel like it belongs in macOS System
Settings, not like a bespoke control panel. When a native pattern
exists, use it; when unsure, ask a `ui-designer` consult framed by
these three priorities before inventing a layout.

**Approachable by default, powerful on demand.** A new user gets a
good tiling setup with almost no configuration; that simplicity
must never *cap* what's achievable — beneath every easy surface is
a deeper layer (Lua config, profiles, advanced layouts, per-space
overrides) there when wanted and never required to begin. Depth is
a capability the user grows into, not a cost paid upfront. The
#326 panel is the shape: a glance surface with one "Edit in
Settings…" bridge down to the full editor.

**The GUI curates, Lua is open.** The GUI is the opinionated gate
that decides what most people *should* touch (safe defaults for
the rest); Lua is the unrestricted power layer. A Lua setter
clamps or rejects only genuinely-broken / unrenderable values (an
invisible alpha, a >1 factor, a malformed color) — never to
enforce taste or a ratio the GUI keeps tidy. Risky-but-valid knob
→ hide it from the GUI, expose it Lua-only, and don't add a guard
that second-guesses the power user (the bars' `dim_factor` /
`active_dim_factor`: Lua-only, clamped to a legible range yet free
to invert the dim ladder).

## Settled conventions — extend, don't relitigate

- **Group by topic, never by widget type.** A toggle and the
  control it gates are one decision, so the toggle sits directly
  *above* the control it gates, never in a separate "toggles"
  block. Colors, which gate nothing, may group by type for grid
  scannability.
- **Grey, don't hide** a control with no effect in the current
  mode (#171) — keep it visible and dimmed. This covers a control
  that *would* work in another mode, so dimming says "switch that
  on and I act".
- An affordance for a channel that **does not exist yet is removed
  outright**: dimming cannot revoke the promise its shape makes,
  and it reads broken instead of forthcoming (the site's App Store
  badge, removed rather than greyed — permanently, the store being
  out of scope; see `docs/design-decisions.md`).
- **The live preview leads** its editor.
- **Defer per-control "why" to contextual help** (the planned `?`
  affordance, #94) rather than bloating labels or captions with
  glosses that would later duplicate it. A caption's job is to
  label what's shown, not to teach.

Shared control conventions (help affordance, control choice, row
tiers) are elaborated in `docs/ui-patterns.md`; the durable
product/UX rulings behind them in `docs/design-decisions.md`.

## File layout

Section bodies in `Settings/Sections/`, their widgets in
`Settings/Components/<area>/` (Layouts, Keybindings, Bars,
SpaceOverrides, Icons, Appearance, Lua, Common). Shell/model files
and root-composed widgets live at `Settings/` root. `Common/`
admits only primitives shared across multiple component areas;
root-owned widgets stay at `Settings/` root.

## SwiftUI traps

- **Cursor changes use `NSCursor.set()`, never push/pop.** A view
  removed under the pointer (a link that deletes itself, a row
  rebuilt by rename) never delivers the balancing
  `onHover(false)`, and hover interleaved with a drag gesture pops
  the wrong entry — a cursor stack cannot balance. Bit the spaces
  drag handle and the link-hover modifier.
- **Keep `body` a shallow container.** A long modifier chain with
  conditional `background` / `overlay` closures, or
  `+`-concatenated string literals inside one `body` expression,
  can exceed the type-checker's budget — and the failure is
  machine-dependent: it compiles locally but dies on the slower CI
  runner ("unable to type-check this expression in reasonable
  time"), so the local verify gate does not catch it. Extract
  chained subviews into private computed properties / funcs and
  hoist concatenated strings into constants. Bit
  `KeyRecorderField`.
- A view `.disabled()` on a `.menu` `Picker` is **unreliable** —
  it blocks selection but won't grey. Never make it the sole gate
  on a side effect; guard the setter too, and grey the picker
  rather than the row so a `?` affordance stays live.

## Strings

Every user-facing string goes through `L("key", "English")` — see
[localization.md](localization.md), including the "Core names, the
GUI narrates" seam (#96).
