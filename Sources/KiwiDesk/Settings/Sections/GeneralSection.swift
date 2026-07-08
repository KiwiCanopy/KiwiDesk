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
                aboutSection
                advancedSection
            }
            .padding(16)
        }
    }

    /// Language (issue #9): "System default" first, then every
    /// shipped locale by its own native name — the picker itself
    /// is the live control, no Save button (`setLanguage`
    /// persists immediately).
    private var languageSection: some View {
        SettingsSection(
            L("general.language.title", "Language")
        ) {
            Picker(
                L("general.language.title", "Language"),
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
            .pickerStyle(.menu)
        }
    }

    private var languageBinding: Binding<String?> {
        Binding(
            get: { model.config.language },
            set: { model.setLanguage($0) }
        )
    }

    /// Shipped locales, native-name-sorted (§4 of the design
    /// brief): "Deutsch", "Français", etc. — never the English
    /// exonym.
    private var sortedLocales: [LocaleOption] {
        localization.available
            .map { LocaleOption(code: $0) }
            .sorted { $0.nativeName < $1.nativeName }
    }

    /// About (#68 §3.9): the wordmark as the canonical logo +
    /// name placement, version and the discreet support link
    /// beneath. Falls back to the pre-logo glyph row when the
    /// bundled resource is missing.
    private var aboutSection: some View {
        SettingsSection(L("general.about.title", "About")) {
            VStack(spacing: 10) {
                aboutBrand
                Text(KiwiDeskVersion.displayString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Link(destination: SupportLinks.koFi) {
                    Label(
                        L(
                            "general.about.support",
                            "Support KiwiDesk"
                        ),
                        systemImage: "heart"
                    )
                }
                .font(.callout)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// The wordmark's name text is fused into the artwork's
    /// compound path, so it can't recolour per appearance.
    /// Instead of a backing card we ship two masters — navy
    /// text for light, off-white for dark — and swap by
    /// `colorScheme`, so the mark melts into the pane in both.
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
        DisclosureGroup(isExpanded: $advancedExpanded) {
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
                Button {
                    model.showLuaEditor = true
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
        } label: {
            Text(L("general.advanced.title", "Advanced"))
                .font(.headline)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
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

    var nativeName: String {
        Locale(identifier: code)
            .localizedString(forIdentifier: code)
            ?? code
    }
}
