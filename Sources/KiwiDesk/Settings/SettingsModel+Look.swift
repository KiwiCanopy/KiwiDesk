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

    /// Paints `colors` onto the draft — the "Keep previous colors"
    /// tick's one write — and answers whether it left the draft
    /// clean, `isDirty` being recomputed on the write (#1752).
    @discardableResult
    func paintColors(_ colors: [String: String]) -> Bool {
        ColorPalette(name: "", colors: colors).apply(to: &config.settings)
        return !isDirty
    }

    /// Re-reads the user looks from the store.
    func refreshLooks() {
        userLooks = lookStore.userLooks()
    }
}
