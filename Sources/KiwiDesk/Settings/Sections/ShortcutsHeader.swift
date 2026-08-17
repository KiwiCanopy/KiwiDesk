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
                // `groupHeading` is the green-emphasis TEXT
                // token (the diff rows' precedent) — `.green`
                // lifts in dark while the app's greens do not,
                // and full-strength `accent` on words reads
                // clickable (dark pass).
                Text(importedNoteText)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.groupHeading)
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
        // Explicitly sealed rather than left to the default
        // style: the two render alike, but only a named style
        // is visible to the guard keeping the accent off button
        // labels.
        .settingsActionButton()
        // Small: it sits inline beside the layer chips and
        // must not read as a peer tab.
        .controlSize(.small)
        .help(importHelp)
    }

    /// The destination group is INTERPOLATED from the key that
    /// labels it rather than named as text (#818): this sentence
    /// said "lands in Advanced" while the drawer had read "Lua
    /// bindings" since #68, so every locale had faithfully
    /// translated a group name no locale draws.
    private var importHelp: String {
        L(
            "shortcuts.import.help",
            "Reads the shortcuts active in init.lua and adds "
                + "them here, matching each combo. Known "
                + "actions sort into the groups below; "
                + "anything else lands in \u{201C}%1$@\u{201D}. "
                + "Review, then Save.",
            L("shortcuts.advanced.title", "Lua bindings")
        )
    }

    private var importedNoteText: String {
        L(
            "shortcuts.imported_note",
            "Shortcuts imported — review below, then %1$@.",
            L("footer.save", "Save")
        )
    }
}
