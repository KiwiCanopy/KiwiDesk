import AppKit
import KiwiDeskCore
import SwiftUI
import UniformTypeIdentifiers

/// Look shelf mutation and file actions (#1684, `LookStore`). A
/// look names a palette, so saving and importing one files its
/// colors in the ONE palette library — never over a palette of
/// the user's.
extension LooksShelf {
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

    /// Where the draft's colors go, said before the save — the one
    /// notice a save always carries.
    func saveNotice(_ typed: String) -> String? {
        let name = trimmed(typed)
        if store.isBuiltinName(name) {
            return L(
                "looks.reserved",
                "That name is a built-in look — choose another."
            )
        }
        guard !name.isEmpty else { return nil }
        if let matching = matchingPalette() {
            return L(
                "looks.colors_use",
                "Colors: uses the palette “%1$@”.",
                matching.name
            )
        }
        return L(
            "looks.colors_new",
            "Colors: will be saved as a new palette “%1$@”.",
            newPaletteName(for: name)
        )
    }

    func saveCurrent(_ typed: String) {
        let name = trimmed(typed)
        guard canSave(name) else { return }
        let paletteName: String
        if let matching = matchingPalette() {
            paletteName = matching.name
        } else {
            paletteName = newPaletteName(for: name)
            try? model.paletteStore.save(
                ColorPalette(name: paletteName, colors: liveColors)
            )
        }
        try? store.save(
            ShelfLook(
                name: name,
                palette: paletteName,
                style: LookKeys.extract(from: model.config.settings)
            )
        )
        saveRequest = nil
        reload()
    }

    private var liveColors: [String: String] {
        ColorPaletteKeys.extract(from: model.config.settings)
    }

    /// A saved palette the draft's colors already read as.
    private func matchingPalette() -> ColorPalette? {
        let live = liveColors
        return model.allPalettes.first { $0.isApplied(matching: live) }
    }

    /// A free palette name for a look called `name`.
    private func newPaletteName(for name: String) -> String {
        let palettes = model.paletteStore
        return Self.uniqueName(base: name) {
            palettes.isBuiltinName($0) || palettes.hasUserPalette($0)
        }
    }

    func nextUserName() -> String {
        uniqueLookName(base: L("looks.default_name", "My Look"))
    }

    func uniqueLookName(base: String) -> String {
        Self.uniqueName(base: base) {
            store.isBuiltinName($0) || store.hasUserLook($0)
        }
    }

    /// `base`, then `base 2`, `base 3`, … skipping taken names.
    static func uniqueName(
        base: String,
        taken: (String) -> Bool
    ) -> String {
        guard taken(base) else { return base }
        var n = 2
        while taken("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
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

    /// Writes the look, with its palette's colors when that palette
    /// is the user's, so the file stands alone on another Mac.
    func exportLook(_ look: ShelfLook) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(look.name).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let palette = model.userPalettes.first { $0.name == look.palette }
        try? store.export(LookExport(look: look, palette: palette), to: url)
    }

    func importLook() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
            let imported = try? store.importLook(from: url)
        else { return }
        var look = imported.look
        look.name = uniqueLookName(base: look.name)
        if let palette = imported.palette {
            look.palette = fileImported(palette)
        }
        try? store.save(look)
        reload()
    }

    /// The palette name an imported palette lands under: an
    /// identical saved one is reused, anything else takes a free
    /// name rather than shadowing one.
    private func fileImported(_ palette: ColorPalette) -> String {
        if let same = model.allPalettes.first(where: {
            $0.name == palette.name && $0.colors == palette.colors
        }) {
            return same.name
        }
        let name = newPaletteName(for: palette.name)
        try? model.paletteStore.save(
            ColorPalette(name: name, colors: palette.colors)
        )
        return name
    }
}
