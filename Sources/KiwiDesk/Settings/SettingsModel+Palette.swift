import KiwiDeskCore

/// Palette apply (#375): kept out of `SettingsModel` for the file
/// ceiling. The palette *library* lives on the model as
/// `paletteStore`; this is just the one-shot paint.
extension SettingsModel {
    /// Applies a palette's colors onto the staged config — a
    /// one-shot paint, identical in lifecycle to a color-field edit
    /// or the Copy-appearance button (dirty now, persisted by the
    /// footer Save), never a live link.
    func applyPalette(_ palette: ColorPalette) {
        palette.apply(to: &config.settings)
        // Kiwi Neon is the glow showcase, but a palette's colors
        // can't set the non-color `border.glow` flag (palettes are
        // color-only, `ColorPaletteKeys`), so switch the bloom on
        // when it's picked. One-directional by design — picking a
        // sober palette later doesn't force glow back off, leaving a
        // user's own choice intact (they toggle it in Focus border).
        //
        // This side-effect is coupled to the GUI apply entry point,
        // not to the palette itself — a future Lua/CLI "apply palette"
        // path would need to re-home it, or Neon would look inert
        // there. And it is deliberately the ONLY behavior-carrying
        // bundled palette: if a second one ever needs a non-color
        // effect, don't grow this into a switch of magic names —
        // revisit whether a schema-level "recommended settings"
        // sidecar is warranted instead (the `_color`-only palette
        // invariant is worth protecting).
        if palette.name == PaletteCatalog.neonName {
            config.settings.borderStyle.glow = true
        }
    }
}
