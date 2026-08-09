import KiwiDeskCore
import SwiftUI

/// The Shortcuts header: the Import button — placed here,
/// visible without scrolling, where the new user it serves can
/// find it — and a label naming which layer the groups below
/// bind into.
///
/// The layer strip itself lives in the Layers card
/// (`LayerStripEditor`), which is where the census places it.
struct ShortcutsHeader: View {
    @ObservedObject var model: SettingsModel
    @Binding var selected: String
    @State private var importedNote = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                editingLabel
                Spacer()
                // Import only offers itself when init.lua has
                // custom Lua (the same condition as the
                // banner): with nothing custom in the file
                // there is nothing it could find, and inside
                // the visual editor active foreign binds have
                // already forced the raw-Lua fallback anyway.
                if model.hasCustomLua,
                    !model.editingStoredProfile
                {
                    importButton
                }
            }
            if importedNote {
                Text(importedNoteText)
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    /// Which layer the rows below belong to — a LABEL, not a
    /// control, and shown only once a second layer exists.
    ///
    /// The census tiers the layer strip `.showMore`, so the strip
    /// itself now lives in the Layers card rather than the header
    /// (owner ruling: the census is the area's authority). But
    /// every group below binds into the SELECTED layer, and an
    /// editor that does not say what it is editing is a trap the
    /// moment a second layer exists — so the header keeps the
    /// fact and gives up the control. With only `default` there
    /// is nothing to disambiguate and it stays silent.
    @ViewBuilder private var editingLabel: some View {
        if model.config.layers.count > 1 {
            Text(
                L(
                    "shortcuts.editing_layer",
                    "Editing the \u{201C}%1$@\u{201D} layer",
                    selected
                )
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Import (#4)

    private var importButton: some View {
        Button {
            model.importCurrentShortcuts()
            if !model.config.layers.contains(where: {
                $0.name == selected
            }) {
                selected = KeyLayer.defaultName
            }
            importedNote = true
        } label: {
            Label(
                L(
                    "shortcuts.import",
                    "Import from init.lua…"
                ),
                systemImage: "square.and.arrow.down"
            )
        }
        // Explicitly `.bordered` rather than left to the default
        // style: the two render alike, but only the named style
        // is visible to the guard keeping the accent off button
        // labels.
        .settingsActionButton()
        // Small: it sits inline beside the layer chips and
        // must not read as a peer tab.
        .controlSize(.small)
        .help(importHelp)
    }

    private var importHelp: String {
        L(
            "shortcuts.import.help",
            "Reads the shortcuts active in init.lua and adds "
                + "them here, matching each combo. Known "
                + "actions sort into the groups below; "
                + "anything else lands in Advanced. Review, "
                + "then Save."
        )
    }

    private var importedNoteText: String {
        L(
            "shortcuts.imported_note",
            "Shortcuts imported — review below, then Save."
        )
    }
}
