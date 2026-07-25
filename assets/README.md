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
| `logo.svg` | `AppMark.png` (512 px) | Sidebar identity (**both** appearances) + runtime Dock icon (`NSApp.applicationIconImage`) while `.regular` |
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

The repo README's own header images are separate, larger raster
copies of the two wordmarks — regenerate them in the same pass:

```sh
sips -s format png --resampleHeightWidthMax 900 \
    assets/logo_wordmark.svg --out assets/logo_wordmark.png
sips -s format png --resampleHeightWidthMax 900 \
    assets/logo_wordmark_dark.svg \
    --out assets/dark_logo_wordmark.png
```

Constraints on the masters (see `BrandAssets.swift`):

- `logo_mono.svg` must stay **pure black on transparency** —
  it ships as a template image that macOS tints.
- **The mark holds its hue across themes; only the wordmark's
  ink is themed** (#479). A logo that changes colour per
  appearance reads as a different brand, and the only real
  reason a dark variant exists is ink contrast — a legibility
  problem on the text, not a hue problem on the green. So
  there is deliberately **no dark symbol master**: `logo.svg`
  serves both appearances, in the app and on the site.
- `logo_wordmark.svg`'s lettering was originally fused into the
  same compound path as the mark's window tiles, which is why
  the retired dark variant recoloured the *whole* logo to gold
  — the two could not be told apart. That path is now **split
  at the gutter between the mark (ends y≈874) and the lettering
  (starts y≈927)**, so the ink family (`#12251a`) appears as
  separate mark paths and text paths. To retheme the lettering,
  change only the text paths' `fill` **and** their matching
  `stroke` (these masters repeat the fill as a hairline stroke;
  missing it outlines every glyph in the old hue).
- The two wordmark masters ship the **same geometry**, differing
  only in the text paths' colour: `#12251a` (forest ink) for
  light, `#E1EEDB` (mist-green) for dark. The About view swaps
  by `colorScheme`. Both keep a **transparent background** so
  the mark melts into the pane. If you edit one, mirror the
  edit in the other.
