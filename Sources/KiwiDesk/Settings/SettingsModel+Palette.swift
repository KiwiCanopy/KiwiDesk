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

    /// Re-reads the user palette names into the search cache
    /// (#805). The store's own mutation points and the window's
    /// reload are its callers (`PaletteNameCacheTests`).
    func refreshPaletteNames() {
        paletteNames = paletteStore.userPalettes().map(\.name)
    }
}
