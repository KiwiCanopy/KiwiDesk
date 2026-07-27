# Vendored: sketchybar-app-font

- Upstream: https://github.com/kvndrsslr/sketchybar-app-font
- Release: **none — built from a fork branch** (see below)
- Source: https://github.com/hajiboy95/sketchybar-app-font
  branch `add_kiwidesk_icon`, commit
  `d42d1c630004a5dd7901749d8bc4c77a14bf62e7`
  (upstream `main` + the `:kiwidesk:` icon, 0 commits behind)
- Built: 2026-07-27, `pnpm i --frozen-lockfile && pnpm run build`
- Vendored: 2026-07-27
- License: CC0-1.0 (see upstream)
- SHA-256:
  - c9125f4be02e2586d564b0e3da63024fedddd520f92f122a6bee32aa64a61d81  sketchybar-app-font.ttf
  - 691b0b2b537de22364d1f8ae3867056ea1a1620cd03b3eec4c151cfe4f1cc853  icon_map.json

**Temporary.** Upstream ships no KiwiDesk glyph yet, and the
release assets are built from the SVGs rather than committed, so
a release download cannot carry a pending contribution. This drop
is therefore built locally from the fork branch that adds it, so
the shipped App Bar can render KiwiDesk's own icon (#294).

Lift it once the icon lands upstream **and** upstream cuts a
release containing it — merge alone is not enough, since
`scripts/update-app-font.sh` pulls release assets. Then re-vendor
normally with `./scripts/update-app-font.sh` and this file returns
to a plain pinned tag. `AppFontResourceTests` asserts the
`KiwiDesk` → `:kiwidesk:` mapping, so a re-vendor that silently
drops the glyph fails at `swift test` instead of shipping a blank
App Bar slot.

Snapshot of the release assets `sketchybar-app-font.ttf` and
`icon_map.json`. Do not hand-edit either file — refresh with
`./scripts/update-app-font.sh` and re-run `swift test` (the
shipped-resource guard tests validate the drop).
