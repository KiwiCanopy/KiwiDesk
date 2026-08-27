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
  # The space/Desktop rule below governs COPY, which is authored
  # in none of the dirs above — #768 swept eleven catalogs, four
  # Onboarding files, the site and ten docs pages, and an author
  # editing any of them would otherwise be handed
  # gui.md/localization.md/docs.md, none of which name the two
  # senses. Same reasoning as the Layouts entry above: the rule
  # has to load where the words are written.
  - "Sources/KiwiDesk/Onboarding/**"
  - "Sources/KiwiDeskCore/Resources/Locales/**"
  - "site/src/i18n/**"
  - "docs/**"
  # README.md is deliberately absent: it is in
  # .github/ci-ignore.txt, and CiPathFilterTests reds on a rule
  # file pinning a path CI skips — a pin nothing builds is a
  # promise nothing keeps.
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
- **pill** — two ruled senses, deliberately (2026-08-10): a
  transient worded on-window cue — the sticky mark's EXPANDED
  state (#435/#438) and, since #933, the size-limit refusal
  flash (`SizeLimitOverlay`) — and the Settings window's
  floating **save pill** (#678 turn 9, always with "save"
  attached in copy and code). The contexts cannot collide —
  one is an on-window overlay, the other Settings chrome —
  which is what a third sense would have to prove before
  joining; the ruling is in `docs/design-decisions.md`
  ▸ the floating pill.
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
- **title** vs **name** — a *title* is the text a window itself
  reports (`app_bar.set_content`'s `title` / `icon_and_title`,
  `app_bar.set_title_cap`, `space_bar.set_title_cap`, the app
  rules' "Title contains…"); a *name* is the label of the app
  that owns the window, which a bar draws only where a title
  cannot speak. Name a new drawn-text knob after the *title*,
  and coin no third word for either; the ruling is
  `docs/design-decisions.md` ▸ The bars name the WINDOW, not
  its app.
- **space** vs **Desktop** — a *space* is one of KiwiDesk's own
  window lists (`SpaceID`, `focus_space`, `space_modes`, the
  Space Bar). Name a macOS Mission Control desktop **Desktop**
  and never a "space" — in a label, a doc sentence or a doc
  comment — and where a sentence names both, write both words:
  one readable either way is the whole defect the rename
  removed. Retired as names for KiwiDesk's: *workspace*,
  *virtual space*. The word also stops naming a generic screen
  area ("empty space", "the available space") — say the width,
  the height or the area that is meant. The **wire is exempt
  and frozen**, so this rule governs copy only; the design
  decision cited at the end of this bullet names which wire
  names those are, and naming them here too would be one list
  rotting in two files. **Quote Apple verbatim** where copy
  names one of
  Apple's own controls — the "Displays have separate Spaces"
  checkbox, the Mission Control shortcut rows
  (`system_shortcut.mission_control_space_*`) — because the
  string's job there is to send the user to a row they can find
  on screen, and a locale must reach for Apple's own translation
  rather than coin a name for someone else's control.
  **In the ENGLISH of a user-facing STRING, capitalise
  KiwiDesk's own noun** (Space, Spaces): the capital is what
  makes the Desktop/Space contrast visible in a sentence naming
  both, and `Sources/KiwiDeskCore/Resources/Locales/en.json` and
  `site/src/i18n/en.json` are the two corpora it binds. It does
  **not** reach an identifier — a census row id, a search
  keyword, a dictionary key — where a capitalisation sweep has
  already once re-keyed `(action) spaces.delete`. Nor does it
  reach `docs/` running prose, which is written about the app
  rather than displayed by it. And it is **not** a claim that the
  word survives translation: `scripts/localization_guards.py`'s
  `PRODUCT_NAMES` is the one register of what must appear
  verbatim in every catalog, "Space" is deliberately absent from
  it. **A translator matches whatever noun their own catalog has
  settled on and never introduces a second** — that is the
  obligation. What the catalogs actually DO is an observation, and
  it was stated wrongly here: as measured 2026-08-17, nine of the
  ten translate it (`スペース`, `공간`, `пространство`, `Espacios`,
  `Espaces`, `Spazi`, `Espaços`, `空间`, `空間`) and **`de`
  keeps the Latin "Spaces"** — its `destination.spaces` IS
  "Spaces" and ~135 of its values use it, so that is `de`'s
  settled answer rather than a lapse. This row previously read
  "every locale rightly translates the noun", which was false for
  one catalog in ten and was then handed to a translation round as
  a constraint, where the drafter refused it against the file
  (#859). Whether `de` should join the nine is a catalog-wide
  sweep and its own ruling. The
  ruling, and the table of names already eliminated so none is
  re-proposed, is `docs/design-decisions.md` ▸ Vocabulary: macOS
  has Desktops, KiwiDesk has Spaces, which also owns the list of
  wire names this rule exempts.
- **screen** vs **display** vs **monitor** — a physical screen is
  a **screen**, in a label, a caption or a doc comment. *Display*
  is reserved for **quoting Apple**: System Settings ▸ Displays,
  the "Displays have separate Spaces" checkbox, anywhere copy
  sends the user to a control Apple named — the same reservation
  the space/Desktop bullet above makes, one noun over, and for
  the same reason. A sentence naming both writes both words.
  Retired as names for a screen: *monitor*, *display*. The
  **wire is exempt**, as it is above: a Lua verb, an event name
  or a profile key spelling either word keeps it until someone
  rules the wire, and this bullet governs copy alone — naming
  those here would be one list rotting in two files, the same
  reason the bullet above names none. A **proper name** is not
  the common noun and is not bound here — the `Coder & Monitor`
  preset keeps its name.

  Two obligations, and no claim about what the corpus currently
  says: **author every new string to this**, and **do not sweep
  the existing ones as a rider on some other branch** — the
  sweep reaches the census, a component directory, the site
  corpus and `docs/`, and it is #865, ruled off 1.0. A locale
  applies the ladder to its OWN file: this settles the English,
  never which of a catalog's two candidates wins there
  (`docs/localization-naming.md` ▸ Family C, whose rule 2 is
  the one copy of how that is decided). The argument, and the
  counts it was decided on, are `docs/design-decisions.md` ▸
  Vocabulary: a screen is a screen.
- **duration** vs **speed** vs **rate** vs **delay** — name the
  quantity you STORE. A time a thing takes is a **duration**
  (`animations.set_duration`,
  `animations.set_scroll_duration`); raising it makes the thing
  slower, which is why "speed" ran backwards and was retired
  from that knob (#1020). A genuine per-second quantity is a
  **rate** (`animations.set_size_rate`, in Hz) and keeps that
  name — the rule is not that "speed" is banned. Time spent
  waiting BEFORE something starts is a **delay**
  (`core.set_wake_restore_delay`), a third quantity again.
  *Speed* survives only as a search synonym, because it is the
  word a user reaches for (`SettingsSearchSynonyms`).
- **animation** vs **motion** — KiwiDesk's own word for its
  window movement is **animation**, in every catalog and in the
  destination that holds it (#1017). *Motion* is reserved for
  quoting Apple's "Reduce Motion", which the same card's help
  text does — using it for our own feature made the destination
  read as the accessibility setting, worst of all in German
  where *Bewegung* is macOS's own word for it.
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
