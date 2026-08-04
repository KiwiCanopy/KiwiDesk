---
paths:
  - "Sources/KiwiDeskCore/Config/**"
  - "Sources/KiwiDeskCore/Profiles/**"
  - "Sources/KiwiDeskCore/Commands/**"
  # The `CodingKeys` and labels the glossary below governs are
  # authored here, not in the three dirs above — scoping this
  # file to Commands alone is why the same nouns drifted twice.
  - "Sources/KiwiDeskCore/Layouts/**"
  - "Sources/KiwiDeskCore/Tiling/**"
  - "Sources/KiwiDeskCore/Borders/**"
  - "Sources/KiwiDeskCore/Bar/**"
  # These author `CodingKeys` and user-facing knobs too — palettes,
  # shared value types, the animation rates.
  - "Sources/KiwiDeskCore/Appearance/**"
  - "Sources/KiwiDeskCore/Models/**"
  - "Sources/KiwiDeskCore/Animation/**"
  - "Sources/KiwiDesk/Settings/**"
---

# Config / profile vocabulary

Canonical for this vocabulary (AGENTS.md §5 indexes it). One
vocabulary spans Lua and profile JSON:

- A profile JSON key is the Lua command name with the `set_` verb
  stripped, snake_case, grouped by namespace:
  `set_gap_override` → `gap.override`, `bsp.set_ratio_h` →
  `layout.bsp.ratio_h`, `stack.set_master_ratio` →
  `layout.stack.master_ratio`. Multi-part element names nest
  further when the element is a configurable unit:
  `drag.set_ghost_fill_color` → `drag.ghost.fill_color`.
- Groups are **singular** (`gap`, `layout`, `drag`); never invent
  synonyms or plurals.
- When adding a setting, pick the Lua name first and derive the
  JSON key via `CodingKeys`. `SettingsCodingTests` pins this shape.

## Noun glossary (R6/#406)

The rules above settle key *derivation*, never which noun to
pick — which is why the same terms drifted twice (#228 split
`tab_background`; R6 renamed it). Reuse these; don't coin a
synonym:

- **mark** — the on-window state glyph (sticky). Retired as a
  name for it: *indicator*, *chip*.
- **badge** — a small disc on a bar item's corner: the group
  count badge, and the Space Bar's sticky / floating state
  badges (`group_badge_*`, `space_bar.sticky_badge`). One
  family, three different corners.
- **pill** — the sticky mark's transient EXPANDED state only.
- **indicator** — the bar's **active-item** marker
  (`active_indicator`): which item is current, never a window's
  state. Live and correct — T1 retired "indicator" only as a
  name for the sticky mark.
- **chip** — a Settings-app token widget (`Settings/Chips.swift`:
  `SpaceChip`, `BadgeChip`, `SpaceAssignmentChip`). Live and
  correct; retired only as a name for the sticky mark.
- **item** — one entry in a bar (a window, a same-app group, a
  space). Its geometry is `item_size` / `item_gap`. Never "tab":
  that word belongs to macOS **native tabs** (§5) and to the
  user guide's gesture prose alone — see
  [state-and-layout.md](state-and-layout.md).
- **width** vs **thickness** — a *stroke* has a width
  (`border.set_width`, `drag.…_border_width`); a *bar* has a
  thickness (`app_bar.set_thickness`).
- **limit** / **cap** / **count** — a `limit` is a user-set
  maximum (`track.set_limit`); `cap` is the same idea where it
  already reads better (`space_bar.set_glyph_cap`, and
  `trackCap` / `normalCap` in code); a `count` is how many exist
  right now. `stack.set_master_count` is a retained exception —
  the user names how many windows are masters, and it shipped
  that way.
- **style** — names WHERE or HOW something is drawn, not what
  the drawn thing is called (`background_style`).
- **layer** — a named alternate keybinding set; only the active
  one fires (`KeyLayer`, `config.layers`, `define_layer` /
  `switch_layer`). Retired as a name for it: *mode*. That word
  is spoken for twice over — a space's layout (`LayoutMode`,
  `space_modes`) and the Settings window's Simple/Power-User depth —
  so a third sense made "switch mode" ambiguous three ways.
  Reserve *mode* for those two; the ruling is
  `docs/design-decisions.md` ▸ Shortcuts.
- **cascade level** — one step of the global ← profile
  resolution. Say this, not "layer", now that *layer* names the
  keybinding set (`docs/lua-reference.md`'s Config Cascade
  section is where the two collide), and not "tier" either:
  *tier* is already spoken for twice over by `SettingTier` /
  row tiers (`docs/ui-patterns.md`) and the bars' dim tiers.

See `docs/design-decisions.md` for each ruling's rationale, and
`docs/ui-patterns.md` ("Labels & wire names") for when a rename
moves the label vs the wire.
