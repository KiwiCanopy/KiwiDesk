---
paths:
  - "Sources/KiwiDeskCore/Config/**"
  - "Sources/KiwiDeskCore/Profiles/**"
  - "Sources/KiwiDeskCore/Commands/**"
---

# Config / profile vocabulary

See AGENTS.md §5 for full rationale. One vocabulary spans Lua and
profile JSON:

- A profile JSON key is the Lua command name with the `set_` verb
  stripped, snake_case, grouped by namespace:
  `set_gap_override` → `gap.override`, `bsp.set_ratio` →
  `layout.bsp.ratio`. Multi-part element names nest further:
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

- **mark** — the on-window state glyph (sticky). Not indicator,
  not chip.
- **badge** — a state or count marker drawn in a *bar's* badge
  slot (`group_badge_*`, `space_bar.sticky_badge`).
- **pill** — the sticky mark's transient EXPANDED state only.
- **item** — one entry in a bar (a window, a same-app group, a
  space). Its geometry is `item_size` / `item_gap`. Never "tab":
  that word belongs to macOS **native tabs** (§5) and to the
  user guide's gesture prose alone.
- **width** vs **thickness** — a *stroke* has a width
  (`border.set_width`, `drag.…_border_width`); a *bar* has a
  thickness (`app_bar.set_thickness`).
- **limit** vs **count** — a `limit` is a cap the user sets
  (`track.set_limit`); a `count` is how many exist right now.
- **style** — names WHERE or HOW something is drawn, not what
  the drawn thing is called (`background_style`).

See `docs/design-decisions.md` for each ruling's rationale, and
`docs/ui-patterns.md` ("Labels & wire names") for when a rename
moves the label vs the wire.
