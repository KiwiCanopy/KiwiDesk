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
    /// Drives the light/dark wordmark swap (see `aboutBrand`).
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                languageSection
                LoginItemCard()
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
    private var languageSection: some View {
        SettingsSection(
            SettingsCatalog.general.languageCard
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
        }
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

    /// About (#68 §3.9): the wordmark as the canonical logo +
    /// name placement, version and the discreet support link
    /// beneath. Falls back to the pre-logo glyph row when the
    /// bundled resource is missing.
    private var aboutSection: some View {
        SettingsSection(SettingsCatalog.general.aboutCard) {
            VStack(spacing: 10) {
                aboutBrand
                Text(KiwiDeskVersion.displayString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Link(destination: SupportLinks.koFi) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                        Text(
                            L(
                                "general.about.support",
                                "Support KiwiDesk"
                            )
                        )
                        .underline()
                    }
                }
                .buttonStyle(.plain)
                .font(.callout)
                .linkHover()
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// The wordmark is artwork, not text, so its ink is baked at
    /// rasterization time rather than tinted at runtime: we ship
    /// two masters — forest lettering for light, mist-green for
    /// dark — and swap by `colorScheme`, so no backing card is
    /// needed and the mark melts into the pane in both. The
    /// **symbol** is identical in the two (#479); only the
    /// lettering is themed, and `BrandMasterParityTests` pins
    /// that.
    @ViewBuilder private var aboutBrand: some View {
        if let wordmark {
            Image(nsImage: wordmark)
                .resizable()
                .scaledToFit()
                .frame(height: 130)
        } else {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text(L("general.about.app_name", "KiwiDesk"))
                    .font(.headline)
            }
        }
    }

    /// The dark master falls back to the light one if it is
    /// ever missing — a readable-but-imperfect degrade beats
    /// showing nothing.
    private var wordmark: NSImage? {
        colorScheme == .dark
            ? BrandAssets.wordmarkDark ?? BrandAssets.wordmark
            : BrandAssets.wordmark
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
                Text(editLuaCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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

    /// The endonym, with its first character capitalized *for
    /// this locale*.
    ///
    /// `localizedString(forIdentifier:)` returns the running-text
    /// form, and Spanish, French, Italian and Russian do not
    /// capitalize a language name mid-sentence — so the raw list
    /// read "English, Deutsch, español, français, italiano,
    /// русский", capitalized only where the language's own
    /// orthography happens to do it. That looks like a bug
    /// because in a *list* it is one: macOS System Settings
    /// capitalizes every entry, and matching it is the
    /// Apple-native call (§2.7).
    ///
    /// Uppercasing with the entry's own locale, not the current
    /// one, keeps a language's own casing rules in charge; scripts
    /// without case (日本語, 한국어, 中文) are returned untouched.
    var nativeName: String {
        let locale = Locale(identifier: code)
        let raw =
            locale.localizedString(forIdentifier: code) ?? code
        guard let first = raw.first else { return raw }
        return String(first).uppercased(with: locale)
            + raw.dropFirst()
    }
}
