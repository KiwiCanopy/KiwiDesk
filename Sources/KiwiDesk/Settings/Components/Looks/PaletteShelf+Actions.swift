import AppKit
import KiwiDeskCore
import SwiftUI
import UniformTypeIdentifiers

/// Palette shelf mutation and file action handlers (#375), each
/// through Core's palette doors (#2875).
extension PaletteShelf {
    /// The one re-read after a shelf mutation (#805).
    func reload() {
        model.refreshPalettes()
    }

    func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Save current

    /// Validation evaluated on typed name string (#843), Core's
    /// one verdict (#2953).
    func canSave(_ typed: String) -> Bool {
        core.paletteNameVerdict(typed).isAllowed
    }

    /// "Overwrite" when the name is an existing user palette, else
    /// "Save" — the Finder duplicate-file idiom.
    func saveLabel(_ typed: String) -> String {
        core.paletteNameVerdict(typed) == .overwrites
            ? L("palettes.overwrite", "Overwrite")
            : L("palettes.save", "Save")
    }

    /// The caption under the field, or nil while there is
    /// nothing to say.
    func saveNotice(_ typed: String) -> String? {
        if core.paletteNameVerdict(typed) == .bundled {
            return L(
                "palettes.reserved",
                "That name is a built-in palette — choose another."
            )
        }
        let live = ColorPaletteKeys.extract(
            from: model.config.settings
        )
        let all = core.allPalettes
        if let matching = all.first(where: {
            $0.isApplied(matching: live)
        }) {
            return L(
                "palettes.already_saved",
                "These colors are already saved as “%1$@”.",
                matching.name
            )
        }
        return nil
    }

    func saveCurrent(_ typed: String) {
        let name = trimmed(typed)
        guard canSave(name) else { return }
        _ = try? core.savePalette(
            named: name,
            from: model.config.settings
        )
        saveRequest = nil
        reload()
    }

    /// The next free "My Palette N" for the save field's default.
    func nextUserName() -> String {
        core.freePaletteName(
            base: L("palettes.default_name", "My Palette")
        )
    }

    // MARK: - Rename / delete

    /// A rename is allowed to a name Core's verdict allows (#2953).
    func canRename(_ typed: String, from oldName: String) -> Bool {
        core.paletteNameVerdict(typed, renaming: oldName).isAllowed
    }

    /// Per-tile rename binding seeded from request (#843).
    func renameBinding(
        _ name: String
    ) -> Binding<NameEditRequest?> {
        Binding(
            get: {
                renameRequest?.subject == name
                    ? renameRequest : nil
            },
            set: { if $0 == nil { renameRequest = nil } }
        )
    }

    func renamePalette(_ typed: String, from oldName: String) {
        let name = trimmed(typed)
        guard canRename(name, from: oldName) else { return }
        // Core's door re-points the looks drawn in it (#1684); a
        // refusal leaves the popover open on the name typed.
        if (try? core.renamePalette(from: oldName, to: name)) != nil {
            renameRequest = nil
        }
        model.refreshLooks()
        reload()
    }

    /// Deletes a palette and directs focus to the neighbouring tile (#816).
    func deletePalette(_ name: String) {
        let neighbour = neighbourAfterDeleting(name)
        try? core.deletePalette(name)
        reload()
        returningTile = neighbour
    }

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
        try? core.exportPalette(palette, to: url)
    }

    func importPalette() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
            (try? core.importPalette(from: url)) != nil
        else { return }
        reload()
    }
}
