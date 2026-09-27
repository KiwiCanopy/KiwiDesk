import KiwiDeskCore

/// Look application for SettingsModel (#1684).
extension SettingsModel {
    var lookStore: LookStore { core.lookLibrary }

    /// Every palette a look may name, bundled first.
    var allPalettes: [ColorPalette] {
        paletteStore.builtins() + userPalettes
    }

    /// The palette `look` names, or nil when it names none or one
    /// no longer saved.
    func palette(of look: ShelfLook) -> ColorPalette? {
        guard let name = look.palette else { return nil }
        return allPalettes.first { $0.name == name }
    }

    /// Paints `look` onto the draft — its styling, and its
    /// palette's colors when `withColors` — one-shot, like a
    /// palette (#375): nothing the look does not name moves.
    func applyLook(_ look: ShelfLook, withColors: Bool) {
        look.apply(
            to: &config.settings,
            palette: withColors ? palette(of: look) : nil
        )
    }

    /// Re-reads the user looks from the store.
    func refreshLooks() {
        userLooks = lookStore.userLooks()
    }
}
