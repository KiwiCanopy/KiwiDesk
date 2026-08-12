import AppKit
import KiwiDeskCore
import SwiftUI
import UniformTypeIdentifiers

/// The palette shelf's actions: save-current, rename, delete, and
/// export/import through Finder panels. Every mutation goes through
/// the stateless `PaletteStore` and then `reload()`s the local
/// list so the grid refreshes (#375).
extension PaletteShelf {
    func reload() {
        userPalettes = store.userPalettes()
    }

    func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Save current

    /// Functions of the TYPED name, not of shelf state (#843):
    /// the popover owns what it edits, so the rule has to be
    /// askable about a name the shelf has never seen.
    func canSave(_ typed: String) -> Bool {
        let name = trimmed(typed)
        return !name.isEmpty && !store.isBuiltinName(name)
    }

    /// "Overwrite" when the name is an existing user palette, else
    /// "Save" — the Finder duplicate-file idiom.
    func saveLabel(_ typed: String) -> String {
        store.hasUserPalette(trimmed(typed))
            ? L("palettes.overwrite", "Overwrite")
            : L("palettes.save", "Save")
    }

    /// The caption under the field, or nil while there is
    /// nothing to say.
    func saveNotice(_ typed: String) -> String? {
        guard store.isBuiltinName(trimmed(typed)) else {
            return nil
        }
        return L(
            "palettes.reserved",
            "That name is a built-in palette — choose another."
        )
    }

    func saveCurrent(_ typed: String) {
        let name = trimmed(typed)
        guard canSave(name) else { return }
        let palette = ColorPalette(
            name: name,
            colors: ColorPaletteKeys.extract(
                from: model.config.settings
            )
        )
        try? store.save(palette)
        savingCurrent = false
        reload()
    }

    /// The next free "My Palette N" for the save field's default.
    func nextUserName() -> String {
        uniqueName(base: L("palettes.default_name", "My Palette"))
    }

    /// `base`, then `base 2`, `base 3`, … skipping every built-in
    /// and existing user name.
    func uniqueName(base: String) -> String {
        guard taken(base) else { return base }
        var n = 2
        while taken("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    private func taken(_ name: String) -> Bool {
        store.isBuiltinName(name) || store.hasUserPalette(name)
    }

    // MARK: - Rename / delete

    /// A rename is allowed to a non-empty name that isn't a
    /// built-in's and isn't already another user palette's (a
    /// no-op rename to the same name is fine).
    func canRename(_ typed: String, from oldName: String) -> Bool {
        let name = trimmed(typed)
        guard !name.isEmpty, !store.isBuiltinName(name) else {
            return false
        }
        return name == oldName || !store.hasUserPalette(name)
    }

    /// Drives a per-tile rename popover: on for the tile whose name
    /// is `renaming`, dismiss clears it.
    func renameBinding(_ name: String) -> Binding<Bool> {
        Binding(
            get: { renaming == name },
            set: { if !$0 { renaming = nil } }
        )
    }

    func renamePalette(_ typed: String, from oldName: String) {
        let name = trimmed(typed)
        guard canRename(name, from: oldName) else { return }
        try? store.rename(from: oldName, to: name)
        renaming = nil
        reload()
    }

    /// Deleting a saved palette lands the keyboard on the next
    /// tile, else the previous, else nothing (#816). Read BEFORE
    /// the delete: `reload()` re-reads the store, so afterwards
    /// the neighbour can only be named by whichever tile slid
    /// into the gap.
    func deletePalette(_ name: String) {
        let neighbour = neighbourAfterDeleting(name)
        try? store.delete(name)
        reload()
        returningTile = neighbour
    }

    /// Grid order is the order `userPalettes` renders in — the
    /// tiles wrap across rows, so "next" is the next tile in
    /// reading order, which is what a keyboard walk follows too.
    func neighbourAfterDeleting(_ name: String) -> String? {
        DeletionFocus.neighbour(
            after: name,
            in: userPalettes.map(\.name)
        )
    }

    // MARK: - Export / import

    func exportPalette(_ palette: ColorPalette) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(palette.name).json"
        guard panel.runModal() == .OK, let url = panel.url
        else { return }
        try? store.export(palette, to: url)
    }

    func importPalette() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
            let imported = try? store.importPalette(from: url)
        else { return }
        // Never shadow a built-in or an existing user palette on
        // import — settle on the next free name.
        let named = ColorPalette(
            name: uniqueName(base: imported.name),
            colors: imported.colors
        )
        try? store.save(named)
        reload()
    }
}
