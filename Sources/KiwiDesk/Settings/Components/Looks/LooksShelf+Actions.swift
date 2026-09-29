import AppKit
import KiwiDeskCore
import SwiftUI
import UniformTypeIdentifiers

/// Look shelf actions (#1684). Every library write goes through
/// Core's one door (`KiwiCore+Looks`); this file narrates.
extension LooksShelf {
    var core: KiwiCore { model.core }

    func reload() {
        model.refreshLooks()
        model.refreshPalettes()
    }

    func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Save current

    func canSave(_ typed: String) -> Bool {
        let name = trimmed(typed)
        return !name.isEmpty && !store.isBuiltinName(name)
    }

    func saveLabel(_ typed: String) -> String {
        store.hasUserLook(trimmed(typed))
            ? L("looks.overwrite", "Overwrite")
            : L("looks.save", "Save")
    }

    /// Why a typed name cannot be saved, said before the save.
    func saveNotice(_ typed: String) -> String? {
        guard store.isBuiltinName(trimmed(typed)) else { return nil }
        return L(
            "looks.reserved",
            "That name is a built-in look — choose another."
        )
    }

    /// Saves the draft's look; a refusal keeps the popover open.
    func saveCurrent(_ typed: String) {
        let name = trimmed(typed)
        guard canSave(name) else { return }
        do {
            try core.saveLook(named: name, from: model.config.settings)
            failure = nil
            saveRequest = nil
        } catch {
            failure = libraryFailure
        }
        reload()
    }

    func nextUserName() -> String {
        KiwiCore.uniqueName(base: defaultName) {
            store.isBuiltinName($0) || store.hasUserLook($0)
        }
    }

    /// A write refused by an unreadable or newer library.
    private var libraryFailure: String {
        L(
            "looks.save_failed",
            "KiwiDesk can't write your saved looks — they may come "
                + "from a newer KiwiDesk."
        )
    }

    private var defaultName: String {
        L("looks.default_name", "My Look")
    }

    // MARK: - Rename / delete

    func canRename(_ typed: String, from oldName: String) -> Bool {
        let name = trimmed(typed)
        guard !name.isEmpty, !store.isBuiltinName(name) else {
            return false
        }
        return name == oldName || !store.hasUserLook(name)
    }

    func renameBinding(_ name: String) -> Binding<NameEditRequest?> {
        Binding(
            get: { renameRequest?.subject == name ? renameRequest : nil },
            set: { if $0 == nil { renameRequest = nil } }
        )
    }

    func renameLook(_ typed: String, from oldName: String) {
        let name = trimmed(typed)
        guard canRename(name, from: oldName) else { return }
        try? store.rename(from: oldName, to: name)
        renameRequest = nil
        reload()
    }

    /// Deletes a look and returns focus to its neighbour (#816).
    func deleteLook(_ name: String) {
        let neighbour = DeletionFocus.neighbour(
            after: name,
            in: model.userLooks.map(\.name)
        )
        try? store.delete(name)
        reload()
        returningTile = neighbour
    }

    // MARK: - Export / import

    /// Writes the look, which owns its colors (#1752), so the file
    /// stands alone on another Mac.
    func exportLook(_ look: ShelfLook) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(look.name).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? store.export(LookExport(look: look), to: url)
    }

    func importLook() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try core.importLook(from: url, fallbackName: defaultName)
            failure = nil
        } catch LookStore.StoreError.invalidFile {
            failure = L(
                "looks.import_failed",
                "That file isn't a KiwiDesk look."
            )
        } catch {
            failure = libraryFailure
        }
        reload()
    }
}
