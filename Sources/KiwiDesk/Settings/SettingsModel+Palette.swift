import KiwiDeskCore

/// Color palette application extension for SettingsModel (#375).
extension SettingsModel {
    /// Applies palette colors onto staged settings
    /// (`ColorPaletteKeys`, #375, #578).
    func applyPalette(_ palette: ColorPalette) {
        palette.apply(to: &config.settings)
    }
}
