import KiwiDeskCore
import SwiftUI

/// General settings section covering language, appearance, login item, and
/// backups (#68, #9).
struct GeneralSection: View {
    @ObservedObject var model: SettingsModel
    @EnvironmentObject private var localization: LocalizationManager
    @State private var advancedExpanded = false
    /// The Reset All confirmation (#634); internal because the row
    /// and dialog live in `GeneralSection+Reset`.
    @State var confirmingReset = false
    /// The backup waiting on its confirm (#606) — the dialog
    /// derives from this, never a second Bool, so the two cannot
    /// disagree.
    @State var pendingRestore: SetupBundle?
    /// Core names the condition, `SetupBackupText` writes the
    /// sentence (#96).
    @State var backupError: SetupBundleError?
    /// The log export's range (#1209) — per-mount, never stored.
    @State var logRange: SettingsModel.LogExportRange = .last15Minutes
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion)
    var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                appliesImmediatelySection
                aboutSection
                advancedSection
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }

    /// Settings that apply immediately without manual saving (#9).
    private var appliesImmediatelySection: some View {
        SettingsSection(
            SettingsCatalog.general.appliesImmediatelyCard
        ) {
            DropdownRow(
                label: L(
                    "general.language.display",
                    "Display language"
                ),
                spokenValue: selectedLanguageName
            ) {
                Picker(
                    L(
                        "general.language.display",
                        "Display language"
                    ),
                    selection: languageBinding
                ) {
                    Text(
                        L(
                            "general.language.system_default",
                            "System default"
                        )
                    )
                    .tag(Optional<String>.none)
                    Divider()
                    ForEach(sortedLocales, id: \.code) { locale in
                        Text(locale.nativeName)
                            .tag(Optional(locale.code))
                    }
                }
            }
            Text(
                L(
                    "general.language.applies",
                    "Changes the moment you pick one."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            appearanceRow
            LoginItemCard(model: model)
        }
    }

    /// Appearance mode selector (#823).
    private var appearanceRow: some View {
        SegmentedPicker(
            L("general.appearance", "Appearance"),
            selection: appearanceBinding,
            options: AppearanceChoice.allCases.map {
                ($0.label, $0)
            }
        )
    }

    private var appearanceBinding: Binding<AppearanceChoice> {
        Binding(
            get: { model.appearance },
            set: { model.setAppearance($0) }
        )
    }

    private var languageBinding: Binding<String?> {
        Binding(
            get: { localization.selection },
            set: { model.setLanguage($0) }
        )
    }

    private var selectedLanguageName: String {
        guard let code = localization.selection else {
            return L(
                "general.language.system_default",
                "System default"
            )
        }
        return sortedLocales.first { $0.code == code }?.nativeName
            ?? code
    }

    /// Shipped locales plus English sorted by native endonym.
    private var sortedLocales: [LocaleOption] {
        (localization.available + ["en"])
            .map { LocaleOption(code: $0) }
            .sorted { $0.nativeName < $1.nativeName }
    }

    private var advancedSection: some View {
        SettingsDisclosure(
            SettingsCatalog.general.generalAdvanced,
            chrome: .card,
            isExpanded: $advancedExpanded
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(
                    L(
                        "general.advanced.config_file",
                        "Configuration file"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text(model.configURL.path)
                        .font(
                            .system(
                                .body,
                                design: .monospaced
                            )
                        )
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button(L("general.advanced.reveal", "Reveal")) {
                        NSWorkspace.shared
                            .activateFileViewerSelecting(
                                [model.configURL]
                            )
                    }
                    .settingsActionButton()
                }
                Divider()
                // Opening the raw editor swaps the primary Save to
                // `.saveLua`, dropping staged visual edits — gated
                // like every other discard path (#515).
                Button {
                    model.discardingEdits(
                        message: L(
                            "discard.lua_editor.message",
                            "The raw editor saves init.lua as "
                                + "text, so the edits you "
                                + "haven't saved are dropped."
                        ),
                        confirmLabel: L(
                            "discard.lua_editor.confirm",
                            "Discard & edit init.lua"
                        )
                    ) {
                        model.showLuaEditor = true
                        model.reload()
                    }
                } label: {
                    Label(
                        L(
                            "general.advanced.edit_lua",
                            "Edit init.lua directly"
                        ),
                        systemImage: "curlybraces"
                    )
                }
                .settingsActionButton()
                Text(editLuaCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                exportBackupRow
                Divider()
                exportLogRows
                resetLadder
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .alert(
            backupError.map(SetupBackupText.title) ?? "",
            isPresented: backupErrorBinding,
            presenting: backupError
        ) { _ in
        } message: { error in
            Text(SetupBackupText.sentence(for: error))
        }
        .alert(
            SetupBackupText.partialTitle,
            isPresented: partialRestoreBinding,
            presenting: model.lastRestoreOutcome
        ) { _ in
        } message: { outcome in
            Text(SetupBackupText.sentence(for: outcome))
        }
        .alert(
            model.logExportProblem.map(LogExportText.title) ?? "",
            isPresented: logExportProblemBinding,
            presenting: model.logExportProblem
        ) { _ in
        } message: { problem in
            Text(LogExportText.sentence(for: problem))
        }
    }

    private var partialRestoreBinding: Binding<Bool> {
        Binding(
            get: { model.lastRestoreOutcome != nil },
            set: { if !$0 { model.lastRestoreOutcome = nil } }
        )
    }

    private var backupErrorBinding: Binding<Bool> {
        Binding(
            get: { backupError != nil },
            set: { if !$0 { backupError = nil } }
        )
    }

    private var editLuaCaption: String {
        L(
            "general.advanced.edit_lua.caption",
            "Opens the integrated Lua editor for custom "
                + "scripting beyond the visual controls."
        )
    }
}

/// Shipped locale option displaying native endonym.
private struct LocaleOption {
    let code: String

    var nativeName: String {
        LocaleNativeName.name(for: code)
    }
}
