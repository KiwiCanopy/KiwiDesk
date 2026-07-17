# Brand assets

Vector masters — the single source of truth for the KiwiDesk
logo. The app never ships these; it bundles pre-rasterized
copies in `Sources/KiwiDesk/Resources/` (plain PNG/TIFF, not
an asset catalog — `swift build` on CI does not run actool).

| Master | Bundled as | Used by |
|---|---|---|
| `logo_mono.svg` | `MenuBarIcon.tiff` (18/36 px) | Menu-bar template icon + quick-menu header |
| `logo_wordmark.svg` | `Wordmark.png` (512 px) | Settings ▸ General ▸ About (light mode) |
| `logo_wordmark_dark.svg` | `WordmarkDark.png` (512 px) | Settings ▸ General ▸ About (dark mode) |
| `logo.svg` | `AppMark.png` (512 px) | Sidebar identity (light mode) + runtime Dock icon (`NSApp.applicationIconImage`) while `.regular` |
| `logo_dark.svg` | `AppMarkDark.png` (512 px) | Sidebar identity (dark mode) — golden variant |
| `logo.svg` | — (reserved) | App-icon (`.icns`) master, once an `.app` bundle exists (#89) |

## Website-only assets

Not bundled in the app — consumed directly by the marketing site
(`site/src/assets/brand` is a symlink to this directory).

| File | Used by |
|---|---|
| `kiwi-canopy.png` | Parent-brand (**KiwiCanopy**) logo in the landing + guide footers (#317). Supplied raster master; no SVG. Astro downsamples it per `widths`. |
| `kiwi-mark.svg` | The kiwi-slice glyph in the site's Simple/Nerd mode toggle. A generic mark, unrelated to any parent-brand wordmark. |

## Regenerating after editing a master

Only macOS built-ins needed (`sips` reads SVG; `tiffutil`
builds the 1x+2x pair):

```sh
cd "$(git rev-parse --show-toplevel)"
R=Sources/KiwiDesk/Resources
sips -s format png --resampleHeightWidthMax 18 \
    assets/logo_mono.svg --out /tmp/mb18.png
sips -s format png --resampleHeightWidthMax 36 \
    assets/logo_mono.svg --out /tmp/mb36.png
tiffutil -cathidpicheck /tmp/mb18.png /tmp/mb36.png \
    -out "$R/MenuBarIcon.tiff"
sips -s format png --resampleHeightWidthMax 512 \
    assets/logo_wordmark.svg --out "$R/Wordmark.png"
sips -s format png --resampleHeightWidthMax 512 \
    assets/logo_wordmark_dark.svg --out "$R/WordmarkDark.png"
sips -s format png --resampleHeightWidthMax 512 \
    assets/logo.svg --out "$R/AppMark.png"
```

Constraints on the masters (see `BrandAssets.swift`):

- `logo_mono.svg` must stay **pure black on transparency** —
  it ships as a template image that macOS tints.
- `logo_wordmark.svg` has its name text fused into the
  artwork's compound path, so it can't recolour at runtime.
  Rather than a backing badge, it ships in two variants —
  navy text for light mode, and `logo_wordmark_dark.svg`
  (text recoloured to warm off-white `#F2F5EC`) for dark. The
  About view swaps by `colorScheme`. Both keep a **transparent
  background** so the mark melts into the pane; if you edit
  one, mirror the geometry in the other and only the text/dark
  elements change colour.
