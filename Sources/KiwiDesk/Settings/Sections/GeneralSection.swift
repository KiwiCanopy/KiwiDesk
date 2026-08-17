import KiwiDeskCore
import SwiftUI

/// Whole App ▸ General (#68 §3.2): genuinely app-wide state,
/// never affected by which profile the banner has open —
/// the Language picker (issue #9), the About area, and the
/// Advanced config-file tools.
struct GeneralSection: View {
    @ObservedObject var model: SettingsModel
    @EnvironmentObject private var localization: LocalizationManager
    /// Advanced is collapsed by default — only interested
    /// users need the config-file path and the raw editor.
    @State private var advancedExpanded = false
    /// The Reset All Settings confirmation (#634). Internal:
    /// the row and dialog live in `GeneralSection+Reset`, and
    /// an extension in another file cannot reach `private`.
    @State var confirmingReset = false
    /// The backup waiting on its confirm (#606) — nil while none
    /// is. The dialog's presentation derives from this rather than
    /// from a second Bool, so the two cannot disagree. Internal
    /// for the same reason as `confirmingReset`: the rows live in
    /// `GeneralSection+Backup`.
    @State var pendingRestore: SetupBundle?
    /// The last export or restore failure, rendered as an alert.
    /// Core names the condition, `SetupBackupText` writes the
    /// sentence (#96).
    @State var backupError: SetupBundleError?
    /// Drives the light/dark wordmark swap (see `aboutBrand`).
    /// Internal, not private: the About block lives in
    /// `GeneralSection+About`, and an extension in another file
    /// cannot reach `private` — the same reason
    /// `confirmingReset` above is internal.
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                appliesImmediatelySection
                installInventorySection
                aboutSection
                advancedSection
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }

    /// Language (issue #9): "System default" first, then every
    /// shipped locale by its own native name — the picker itself
    /// is the live control, no Save button (`setLanguage`
    /// persists immediately).
    /// Turn 14b's first group: ONE card, because these rows are
    /// grouped by the RULE they share rather than by topic —
    /// none is part of a profile, none is touched by the
    /// footer's Save. Splitting them into a Language card and a
    /// Login card is what let Revert look as though it would
    /// undo them (the 6b audit's fourth finding).
    private var appliesImmediatelySection: some View {
        SettingsSection(
            SettingsCatalog.general.appliesImmediatelyCard
        ) {
            // Uses the house `DropdownRow` (shared label axis,
            // `.menu` style, large control) like every other
            // dropdown. The native `.menu` first-letter type-ahead
            // suffices for a short list; revisit with a searchable
            // list (`.searchable` in a popover) once shipped
            // locales approach ~15–20.
            DropdownRow(
                // The card heading is already the topic noun
                // "Language"; the control's own label is the more
                // specific "Display language" so the two don't
                // read as a doubled word (ui-designer 2026-07-28).
                label: L(
                    "general.language.display",
                    "Display language"
                )
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

    /// Item 8. Sits beside the language pick because the two
    /// share a rule rather than a topic: both apply the instant
    /// you choose, neither is part of a profile, and neither is
    /// touched by the footer's Save. Turn 14b makes that the
    /// group's heading, because a row Revert appears to undo and
    /// does not is the 6b audit's fourth finding.
    ///
    /// A segmented control rather than a dropdown: three fixed,
    /// mutually exclusive choices whose whole set fits on one
    /// line is the case `docs/ui-patterns.md` gives segmented,
    /// and unlike the locale list it can never grow.
    /// A direct `SegmentedPicker`, not one inside a
    /// `DropdownRow` (#823): the shared component draws its own
    /// `SettingsRowShape` when it carries a label, and
    /// `DropdownRow` forces `.pickerStyle(.menu)` onto whatever
    /// it wraps. So the wrapper comes off rather than the picker
    /// inside it changing.
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

    /// The picker's concrete languages: every shipped locale file
    /// plus English, native-name-sorted ("Deutsch", "English",
    /// "Français"). English never ships as a runtime file (it
    /// lives inline at call sites) but must be an explicit choice
    /// — otherwise a user on a non-English OS can only reach
    /// English via "System default", which resolves to *their* OS
    /// language, leaving no way to force English.
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
                restartOnCrashRow
                Divider()
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
                // Opening the raw editor swaps the primary Save
                // to `.saveLua`, which writes `luaSource`
                // verbatim — so staged visual edits are dropped
                // while the footer still reads "Unsaved
                // changes". Gated like every other discard
                // path (#515).
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
                        // Discard for real, or the dialog lies:
                        // flipping the flag alone leaves `config`
                        // staged and `isDirty` true, so the footer
                        // still reads "Unsaved changes" and
                        // leaving again prompts a second time for
                        // edits the user already discarded. Flag
                        // first, then reload — `liveState()`
                        // carries `showLuaEditor` through, and
                        // this is the exact mirror of "Back to
                        // visual editor".
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
                // Read-only, so it sits ABOVE the ladder; its
                // destructive twin is the ladder's last rung. The
                // argument is in `GeneralSection+Backup`.
                exportBackupRow
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
            // No button of our own: an empty actions builder makes
            // SwiftUI supply the standard dismissal, localized by
            // the SYSTEM — so it reads correctly even in a
            // language KiwiDesk does not ship a catalog for, which
            // an `L("alert.ok", "OK")` of ours could not. The
            // binding clears the error on dismissal.
        } message: { error in
            Text(SetupBackupText.sentence(for: error))
        }
        // A restore that happened but could not take everything.
        // Its own alert rather than a branch inside the error one:
        // it is not a failure, and a title claiming otherwise
        // would send the user hunting for a problem that is not
        // there.
        .alert(
            SetupBackupText.partialTitle,
            isPresented: partialRestoreBinding,
            presenting: model.lastRestoreOutcome
        ) { _ in
        } message: { outcome in
            Text(SetupBackupText.sentence(for: outcome))
        }
    }

    private var partialRestoreBinding: Binding<Bool> {
        Binding(
            get: { model.lastRestoreOutcome != nil },
            set: { if !$0 { model.lastRestoreOutcome = nil } }
        )
    }

    /// Presented exactly while an error is held — one source of
    /// truth rather than a Bool beside an Optional.
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

/// One shipped locale, presented by its own native name (e.g.
/// "Deutsch" for `de`) — never the English exonym.
private struct LocaleOption {
    let code: String

    /// The endonym, through the one shared derivation
    /// (`LocaleNativeName` carries the casing argument) — the
    /// Home card's language line renders the same call, so the
    /// two surfaces cannot drift.
    var nativeName: String {
        LocaleNativeName.name(for: code)
    }
}
