import KiwiDeskCore

/// Color palette application extension for SettingsModel (#375).
extension SettingsModel {
    /// Applies palette colors onto staged settings — a sparse
    /// paint of `ColorPaletteKeys`, colors-only (#375): no
    /// name-check may toggle a non-color flag (the retracted Neon
    /// glow write, #578; design-decisions "colors-only").
    func applyPalette(_ palette: ColorPalette) {
        palette.apply(to: &config.settings)
    }
}
