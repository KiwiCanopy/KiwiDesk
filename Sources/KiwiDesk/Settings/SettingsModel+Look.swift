import Foundation
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
    /// not name moves. A pick, so it records the look's origin.
    func applyLook(_ look: ShelfLook) {
        look.pick(into: &config.settings)
    }

    /// Wears a look a gallery link added as an unsaved change, its
    /// tile marked (#1740 ▸ Step 3 decisions): on Simple's Look line
    /// while Simple shows, else on the Looks page. Call after the
    /// window is shown, whose fresh open reloads the draft.
    func wearLinkedLook(_ look: ShelfLook) {
        refreshLooks()
        linkedLook = look.name
        applyLook(look)
        guard !showsSimple else { return }
        land(on: SettingsAnchor(destination: .looks))
    }

    /// Paints `colors` onto the draft — the "Keep previous colors"
    /// tick's one write — and answers whether it left the draft
    /// clean, `isDirty` being recomputed on the write (#1752).
    @discardableResult
    func paintColors(_ colors: [String: String]) -> Bool {
        ColorPalette(name: "", colors: colors).apply(to: &config.settings)
        return !isDirty
    }

    /// Whether `typed` may rename the user look `old`: not blank,
    /// no bundled look's name, and no other user look's.
    func canRenameUserLook(_ typed: String, from old: String) -> Bool {
        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !lookStore.isBuiltinName(name) else {
            return false
        }
        return name == old || !lookStore.hasUserLook(name)
    }

    /// Renames a user look; a gallery link on it follows the name,
    /// so Simple's line keeps the look (#2860).
    func renameUserLook(from old: String, to typed: String) {
        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canRenameUserLook(name, from: old) else { return }
        try? lookStore.rename(from: old, to: name)
        if linkedLook == old { linkedLook = name }
        refreshLooks()
    }

    /// Deletes a user look; a gallery link on it goes with it.
    func deleteUserLook(_ name: String) {
        try? lookStore.delete(name)
        refreshLooks()
    }

    /// Re-reads the user looks from the store, forgetting a linked
    /// look the library no longer holds.
    func refreshLooks() {
        userLooks = lookStore.userLooks()
        if !userLooks.contains(where: { $0.name == linkedLook }) {
            linkedLook = nil
        }
    }
}
