import KiwiDeskCore

/// Look application for SettingsModel (#1684).
extension SettingsModel {
    var lookStore: LookStore { core.lookLibrary }

    /// Every palette, bundled first, from the model's copy of the
    /// user library (#805).
    var allPalettes: [ColorPalette] {
        paletteStore.builtins() + userPalettes
    }

    /// Paints `look` onto the draft — its styling and its colors
    /// — one-shot, like a palette (#375): nothing the look does
    /// not name moves.
    func applyLook(_ look: ShelfLook) {
        look.apply(to: &config.settings)
    }

    /// Re-reads the user looks from the store.
    func refreshLooks() {
        userLooks = lookStore.userLooks()
    }
}
