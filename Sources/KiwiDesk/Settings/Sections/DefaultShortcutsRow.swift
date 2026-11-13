import KiwiDeskCore
import SwiftUI

/// The Default shortcuts row under the Layers card (#3074): Restore
/// and, while `init.lua` holds shortcuts, Import (#4, #1096), in
/// the `SettingsActionRow` shape Files & Reset uses. Drawn while the
/// `default` layer is selected alone, since its defaults are that
/// layer's (#3260); what Restore does is its `?`, and a caption
/// states only that nothing is left to restore (#3178).
struct DefaultShortcutsRow: View {
    @ObservedObject var model: SettingsModel
    @Binding var selected: String
    @State private var importedNote = false
    @State private var confirmingReset = false
    /// Who else changed the seeded rows, read as the dialog opens
    /// (#3248): empty asks as before, and the restore stays here.
    @State private var elsewhere: [String] = []
    /// The other profiles' own rows "every profile" removes, read
    /// with `elsewhere`.
    @State private var lostElsewhere = 0

    /// Why Restore greys, nil while it acts — the caption reads it.
    private var restoreReason: ShortcutsGates.InertReason? {
        ShortcutsGates(
            config: model.config,
            selectedLayer: selected,
            defaultsToRestore: model.hasDefaultsToRestore
        ).inertReason(for: .shortcuts(.restoreDefaults))
    }

    var body: some View {
        let reason = restoreReason
        // A selection is not a mode: off `default` the container
        // leaves with the layer it belongs to (#3260).
        if reason != .otherLayerPicked {
            container(reason)
        }
    }

    private func container(
        _ reason: ShortcutsGates.InertReason?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsActionRow(
                title: L(
                    "shortcuts.restore_defaults.row",
                    "Default shortcuts"
                ),
                caption: caption(reason),
                help: restoreExplain,
                helpSubject: restoreName
            ) {
                HStack(spacing: 8) {
                    if model.hasCustomLua,
                        !model.editingStoredProfile
                    {
                        importButton
                    }
                    resetButton(reason)
                }
            }
            .padding(12)
            .background(SettingsCardPlate())
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

    /// Restores shipped shortcut defaults onto default layer (#1096),
    /// greyed while they are all in place (#171).
    private func resetButton(
        _ reason: ShortcutsGates.InertReason?
    ) -> some View {
        Button(L("shortcuts.restore_defaults.short", "Restore…")) {
            elsewhere = model.shortcutsRestoreChangedElsewhere
            lostElsewhere =
                elsewhere.isEmpty ? 0 : model.shortcutsRestoreLostElsewhere
            confirmingReset = true
        }
        .settingsActionButton()
        .accessibilityLabel(restoreName)
        .modifier(
            GreyOut(active: reason != nil, help: caption(reason) ?? "")
        )
        .confirmationDialog(
            L(
                "shortcuts.restore_defaults.title",
                "Restore the default shortcuts?"
            ),
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            if let profile = model.reachProfile, !elsewhere.isEmpty {
                Button {
                    model.resetShortcutsToDefaults(reach: .here)
                } label: {
                    Text(RestoreReachWords.here(profile))
                }
                .keyboardShortcut(.defaultAction)
                Button(role: .destructive) {
                    model.resetShortcutsToDefaults(reach: .everyProfile)
                } label: {
                    Text(RestoreReachWords.everyProfile)
                }
            } else {
                Button(role: .destructive) {
                    model.resetShortcutsToDefaults(reach: .here)
                } label: {
                    Text(
                        L(
                            "shortcuts.restore_defaults.confirm",
                            "Restore Defaults"
                        )
                    )
                }
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
            if confirmingReset { Text(resetMessage + changedLine) }
        }
    }

    /// Who else changed the seeded rows, after the counts, then what
    /// "every profile" takes from them.
    private var changedLine: String {
        guard !elsewhere.isEmpty else { return "" }
        let lost =
            lostElsewhere > 0
            ? "\n" + RestoreReachWords.lostElsewhere(lostElsewhere) : ""
        return "\n\n" + RestoreReachWords.changedIn(elsewhere) + lost
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

    /// The live state's line; nil while Restore acts, its fixed
    /// explanation being the `?`'s (#3178).
    private func caption(
        _ reason: ShortcutsGates.InertReason?
    ) -> String? {
        switch reason {
        case nil:
            return nil
        // `.otherLayerPicked` draws no row, and the others are other
        // keys' reasons; listed so a new case asks for its sentence.
        case .matchesDefaults?, .otherLayerPicked?, .onlyDefaultLayer?,
            .trackUnused?,
            .appWideLuaOwned?, .storedProfilePage?, .noBarShows?,
            .focusBorderOff?:
            return L(
                "shortcuts.restore_defaults.at_defaults",
                "Every default shortcut is in place."
            )
        }
    }

    /// What Restore puts back and keeps, then how it asks.
    private var restoreExplain: String {
        restoresWhat + "\n\n" + restoreAsks
    }

    private var restoresWhat: String {
        L(
            "shortcuts.restore_defaults.help",
            "Puts back the shortcuts KiwiDesk provides, "
                + "including ones added since you installed "
                + "it. Shortcuts you added under "
                + "\u{201C}%1$@\u{201D} and \u{201C}%2$@\u{201D} "
                + "are kept.",
            SettingsCatalog.shortcuts.openApplications.text,
            SettingsCatalog.shortcuts.luaBindings.control.text
        )
    }

    private var restoreAsks: String {
        L(
            "shortcuts.restore_defaults.explain",
            "Only the “default” layer has shipped shortcuts; "
                + "the layers you add are yours alone. Before "
                + "anything changes, you are told how many "
                + "shortcuts come back and how many of yours "
                + "are lost because they use a key a default "
                + "needs. Your init.lua is never changed."
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
