import KiwiDeskCore
import SwiftUI

/// The Default shortcuts row under the Layers card (#3074): Restore
/// and, while `init.lua` holds shortcuts, Import (#4, #1096), in
/// the `SettingsActionRow` shape Files & Reset uses. Always drawn;
/// Restore greys with its reason as the caption.
struct DefaultShortcutsRow: View {
    @ObservedObject var model: SettingsModel
    @Binding var selected: String
    @State private var importedNote = false
    @State private var confirmingReset = false

    /// Why Restore is live or greyed — the caption reads it.
    enum RestoreState: Equatable {
        case available
        /// The layer picked above has no shipped defaults.
        case otherLayer
        /// The default layer already matches the shipped set.
        case atDefaults
    }

    static func restoreState(
        layer: String,
        hasDefaultsToRestore: Bool
    ) -> RestoreState {
        if layer != KeyLayer.defaultName { return .otherLayer }
        return hasDefaultsToRestore ? .available : .atDefaults
    }

    var body: some View {
        let state = Self.restoreState(
            layer: selected,
            hasDefaultsToRestore: model.hasDefaultsToRestore
        )
        VStack(alignment: .leading, spacing: 8) {
            SettingsActionRow(
                title: L(
                    "shortcuts.restore_defaults.row",
                    "Default shortcuts"
                ),
                caption: caption(state),
                help: restoreExplain,
                helpSubject: restoreName
            ) {
                HStack(spacing: 8) {
                    if model.hasCustomLua,
                        !model.editingStoredProfile
                    {
                        importButton
                    }
                    resetButton(state)
                }
            }
            .padding(12)
            .background(plate)
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
            ForEach(Array(model.importRenames.enumerated()), id: \.offset) {
                Text(LayerReachWords.importRenamed($0.element))
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.groupHeading)
            }
        }
    }

    /// The page's card plate, so the row reads as one of them.
    private var plate: some View {
        RoundedRectangle(cornerRadius: SettingsTheme.sectionRadius)
            .fill(SettingsTheme.card)
            .overlay(
                RoundedRectangle(
                    cornerRadius: SettingsTheme.sectionRadius
                )
                .strokeBorder(
                    SettingsTheme.hairline,
                    lineWidth: SettingsTheme.containerStroke
                )
            )
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
            KeybindingCatalog.localizedName(
                of: entry.kept,
                config: config
            ),
            ShortcutsReferenceBuilder.glyphs(entry.kept.combo)
        )
    }

    /// The census label: what VoiceOver calls the short button.
    private var restoreName: String {
        L("shortcuts.restore_defaults", "Restore Defaults…")
    }

    /// Restores shipped shortcut defaults onto default layer (#1096).
    /// Greyed, never removed, off the default layer (#171).
    private func resetButton(_ state: RestoreState) -> some View {
        Button(L("shortcuts.restore_defaults.short", "Restore…")) {
            confirmingReset = true
        }
        .settingsActionButton()
        .accessibilityLabel(restoreName)
        .modifier(
            GreyOut(active: state != .available, help: caption(state))
        )
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
            // Counted only while asked: every page render built it
            // (#2783).
            if confirmingReset { Text(resetMessage) }
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
        // "·" never a comma: six locales use the comma as a decimal
        // separator. Save is not named as text (#818).
        return L(
            "shortcuts.restore_defaults.message",
            "Your own shortcuts are kept, except any that use a "
                + "key the defaults need. Shortcuts restored: "
                + "%1$d · your own that are lost: %2$d",
            restored,
            lost
        )
    }

    private func caption(_ state: RestoreState) -> String {
        switch state {
        case .available:
            return L(
                "shortcuts.restore_defaults.help",
                "Puts back the shortcuts KiwiDesk provides, "
                    + "including ones it has added since you "
                    + "installed it. Shortcuts you made yourself "
                    + "are kept."
            )
        case .otherLayer:
            return L(
                "shortcuts.restore_defaults.other_layer",
                "Only the “default” layer has defaults to "
                    + "restore. Pick it in %1$@ above.",
                SettingsCatalog.shortcuts.layersCard.control.text
            )
        case .atDefaults:
            return L(
                "shortcuts.restore_defaults.at_defaults",
                "Your shortcuts match the defaults."
            )
        }
    }

    private var restoreExplain: String {
        L(
            "shortcuts.restore_defaults.explain",
            "Only the “default” layer has shipped shortcuts; "
                + "the layers you add are yours alone. Before "
                + "anything changes, you are told how many "
                + "shortcuts come back and how many of yours "
                + "are lost because they use a key a default "
                + "needs."
        )
    }

    /// Import button reading shortcuts from init.lua (#4, #818).
    private var importButton: some View {
        Button(L("shortcuts.import", "Import from init.lua…")) {
            model.importCurrentShortcuts()
            if !model.config.layers.contains(where: {
                $0.name == selected
            }) {
                selected = KeyLayer.defaultName
            }
            importedNote = true
        }
        .settingsActionButton()
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
