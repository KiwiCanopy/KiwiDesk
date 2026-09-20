import KiwiDeskCore
import SwiftUI

/// Home's lower half (#1536): the community and support links, then
/// one footer line — mark, name, version, update state, About. A
/// quiet strip below the card grid: no container, no rule, marks in
/// secondary ink, so the grid stays the page's only object.
struct HomeSupportStrip: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.openAbout) private var openAbout

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                HomeGroupHeading(
                    L("home.support.heading", "Community & Support")
                )
                FlowLayout(spacing: 12) {
                    SupportLinkRow(
                        mark: BrandAssets.markTelegram,
                        title: L("home.support.telegram", "Join on Telegram"),
                        caption: L(
                            "home.support.telegram.caption",
                            "Questions, ideas and polls — the "
                                + "discussions that shape KiwiDesk."
                        ),
                        url: SupportLinks.telegram
                    )
                    SupportLinkRow(
                        mark: BrandAssets.markGitHub,
                        title: L("home.support.github", "View on GitHub"),
                        caption: L(
                            "home.support.github.caption",
                            "Feature requests, bug reports, source code."
                        ),
                        url: SupportLinks.gitHub
                    )
                    SupportLinkRow(
                        mark: BrandAssets.markKofi,
                        title: L("home.support.kofi", "Support KiwiDesk"),
                        caption: L(
                            "home.support.kofi.caption",
                            "A one-time tip or monthly support, via Ko-fi."
                        ),
                        url: SupportLinks.koFi
                    )
                }
            }
            footer
        }
        .padding(.top, 8)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let mark = BrandAssets.appMark {
                Image(nsImage: mark)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)
            }
            Text(L("general.about.app_name", "KiwiDesk"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SettingsTheme.ink)
            Text(L("general.version", "v%1$@", KiwiDeskVersion.semantic))
                .font(.system(size: 11))
                .foregroundStyle(SettingsTheme.ink3)
                .textSelection(.enabled)
            Text("·")
                .font(.system(size: 11))
                .foregroundStyle(SettingsTheme.ink3)
                .accessibilityHidden(true)
            UpdateStateRow(
                store: model.updater.updates,
                check: { model.updater.checkForUpdates() }
            )
            Spacer(minLength: 8)
            Button(action: openAbout) {
                Text(L("home.footer.about", "About KiwiDesk")).underline()
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
            .linkHover()
        }
    }
}

/// One link of the strip: the service's mark in secondary ink, an
/// underlined title that opens the URL, one line of what it is.
private struct SupportLinkRow: View {
    let mark: NSImage?
    let title: String
    let caption: String
    let url: URL

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            if let mark {
                Image(nsImage: mark)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(SettingsTheme.ink2)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Link(destination: url) {
                    Text(title).underline()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .linkHover()
                Text(caption)
                    .font(.system(size: 10))
                    .foregroundStyle(SettingsTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: 300, alignment: .leading)
    }
}

/// The footer's About action, handed down by the shell that hosts
/// the sheet (`SheetPresentationSeamTests`).
struct OpenAboutKey: EnvironmentKey {
    static let defaultValue: @MainActor () -> Void = {}
}

extension EnvironmentValues {
    var openAbout: @MainActor () -> Void {
        get { self[OpenAboutKey.self] }
        set { self[OpenAboutKey.self] = newValue }
    }
}
