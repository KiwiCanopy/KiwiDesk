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
    }
}
