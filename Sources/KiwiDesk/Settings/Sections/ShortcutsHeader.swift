import KiwiDeskCore
import SwiftUI

/// Header for Shortcuts section with active layer label, Import, and Restore
/// Defaults (#4, #1096).
struct ShortcutsHeader: View {
    @ObservedObject var model: SettingsModel
    @Binding var selected: String
    @State private var importedNote = false
    @State private var confirmingReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                editingLabel
                Spacer()
                if model.hasCustomLua,
                    !model.editingStoredProfile
                {
                    importButton
                }
                if model.hasDefaultsToRestore {
                    resetButton
                }
            }
            if importedNote {
                Text(importedNoteText)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.groupHeading)
            }
            ForEach(Array(droppedLines.enumerated()), id: \.offset) {
                Text($0.element)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.groupHeading)
            }
        }
    }

    /// One line per chord the import or adoption left out (#1807).
    private var droppedLines: [String] {
        model.droppedChords.map {
            Self.droppedLine($0, config: model.config)
        }
    }

    /// Names the chord left out and the one its action kept, the
    /// action by its localized row label.
    static func droppedLine(
        _ entry: NavigationChords.Dropped,
        config: GuiConfig
    ) -> String {
        L(
            "shortcuts.dropped_chord",
            "%1$@ left out: “%2$@” already has %3$@.",
            ShortcutsReferenceBuilder.glyphs(entry.dropped.combo),
            entry.kept.label.isEmpty
                ? entry.kept.lua
                : KeybindingCatalog.localizedLabel(
                    for: entry.kept.label,
                    config: config
                ),
            ShortcutsReferenceBuilder.glyphs(entry.kept.combo)
        )
    }

    /// Names the active layer once there is a choice — the one
    /// `layersExist` reading, asked rather than counted (#1127).
    /// Only the CONDITION is shared with the preview panel: this
    /// names the selection, the panel the layer it drew, which
    /// differ for the frame between a delete and the repair.
    @ViewBuilder private var editingLabel: some View {
        if ShortcutsGates(config: model.config).layersExist {
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

    /// Restores shipped shortcut defaults onto default layer (#1096).
    private var resetButton: some View {
        Button {
            confirmingReset = true
        } label: {
            Label(
                L(
                    "shortcuts.restore_defaults",
                    "Restore Defaults…"
                ),
                systemImage: "arrow.counterclockwise"
            )
        }
        .settingsActionButton()
        .controlSize(.small)
        .disabled(selected != KeyLayer.defaultName)
        .help(resetHelp)
        .confirmationDialog(
            L(
                "shortcuts.restore_defaults.title",
                "Restore the default shortcuts?"
            ),
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                model.resetShortcutsToDefaults()
            } label: {
                Text(
                    L(
                        "shortcuts.restore_defaults.confirm",
                        "Restore Defaults"
                    )
                )
            }
            Button(role: .cancel) {
            } label: {
                Text(
                    L("spaces.delete_confirm.cancel", "Cancel")
                )
            }
        } message: {
            Text(resetMessage)
        }
    }

    /// Explains restored defaults count and collateral loss count (#1096).
    private var resetMessage: String {
        let restored = model.shortcutsTheResetWouldRestore
        let lost = model.shortcutsTheResetWouldDiscard
        if lost == 0 {
            return L(
                "shortcuts.restore_defaults.message_clean",
                "Nothing of yours is lost. Shortcuts "
                    + "restored: %1$d",
                restored
            )
        }
        // "·" never a comma — six locales use the comma as a
        // decimal separator, so "restored: 12, and" reads as a
        // number.
        // Naming Save as literal text is the #818 violation, and
        // interpolating it reds `InterpolatedLabelTests`; filed —
        // the staged-ness beat returns once the frame can say it.
        return L(
            "shortcuts.restore_defaults.message",
            "Your own shortcuts are kept, except any that use a "
                + "key the defaults need. Shortcuts restored: "
                + "%1$d · your own that are lost: %2$d",
            restored,
            lost
        )
    }

    private var resetHelp: String {
        selected == KeyLayer.defaultName
            ? L(
                "shortcuts.restore_defaults.help",
                "Puts back the shortcuts KiwiDesk provides, "
                    + "including ones it has added since you "
                    + "installed it. Shortcuts you made yourself "
                    + "are kept."
            )
            : L(
                "shortcuts.restore_defaults.help_other_layer",
                "Only the default layer has defaults to restore "
                    + "— this one is yours."
            )
    }

    /// Import button reading shortcuts from init.lua (#4, #818).
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
        .settingsActionButton()
        .controlSize(.small)
        .help(importHelp)
    }

    /// The destination group is interpolated from the key that
    /// labels it, never named as text (#818).
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
