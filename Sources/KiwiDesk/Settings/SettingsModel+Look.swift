import Foundation
import KiwiDeskCore

/// Look application for SettingsModel (#1684).
extension SettingsModel {
    /// Every palette, bundled first, from the model's copy of the
    /// user library (#805).
    var allPalettes: [ColorPalette] {
        core.bundledPalettes + userPalettes
    }

    /// Paints `look` onto the draft — its styling and its colors
    /// — one-shot, like a palette (#375): nothing the look does
    /// not name moves. A pick, so it records the look's origin.
    func applyLook(_ look: ShelfLook) {
        look.pick(into: &config.settings)
    }

    /// Wears a look a gallery link added as an unsaved change, its
    /// tile marked (#1740 ▸ Step 3 decisions): on Simple's Look line
    /// while Simple shows, else on the Looks page. Call after
    /// `prepareToShow`'s reload and before the window fronts
    /// (`SettingsWindowController.show(beforeFront:)`, #2863).
    func wearLinkedLook(_ look: ShelfLook) {
        refreshLooks()
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

    /// Whether `typed` may rename the user look `old`, Core's one
    /// verdict (#2953).
    func canRenameUserLook(_ typed: String, from old: String) -> Bool {
        core.lookNameVerdict(typed, renaming: old).isAllowed
    }

    /// Renames a user look; it keeps its place in My looks (#2860).
    func renameUserLook(from old: String, to typed: String) {
        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canRenameUserLook(name, from: old) else { return }
        try? core.renameLook(from: old, to: name)
        refreshLooks()
    }

    /// Deletes a user look.
    func deleteUserLook(_ name: String) {
        try? core.deleteLook(name)
        refreshLooks()
    }

    /// Re-reads the user looks from Core's door.
    func refreshLooks() {
        userLooks = core.userLooks
    }
}
