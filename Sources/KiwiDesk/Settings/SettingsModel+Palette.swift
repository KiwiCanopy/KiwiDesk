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
        // A palette is a colors-only shelf (#375): a sparse paint of
        // `ColorPaletteKeys` onto the staged config, nothing else.
        // No name-check side-effect turns a non-color flag on —
        // Kiwi Neon used to force `border.glow = true` here, but that
        // was one-directional (a later sober palette couldn't clear
        // it, so glow stuck on) and a category error: a color pick
        // silently mutating an unrelated Focus-border toggle the user
        // may have set on purpose. Neon's identity is its own vivid
        // colors; the glow pairing is surfaced as a discoverable
        // link under its swatch (#578), not a hidden write. See the
        // #375 "colors-only" entry in docs/design-decisions.md.
        palette.apply(to: &config.settings)
    }
}
