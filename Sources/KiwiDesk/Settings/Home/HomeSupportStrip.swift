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
                        mark: BrandAssets.markDiscord,
                        title: L(
                            "home.support.discord",
                            "Join the Discord server"
                        ),
                        caption: discordCaption,
                        url: SupportLinks.discord
                    )
                    SupportLinkRow(
                        mark: BrandAssets.markGitHub,
                        title: L("home.support.github", "View on GitHub"),
                        caption: gitHubCaption,
                        url: SupportLinks.gitHub
                    )
                    SupportLinkRow(
                        mark: BrandAssets.markKofi,
                        title: L("home.support.kofi", "Support KiwiDesk"),
                        caption: koFiCaption,
                        url: SupportLinks.koFi
                    )
                }
            }
            // The links follow the last group at the group spacing;
            // only the footer line takes the leftover height.
            Spacer(minLength: 20)
            footer
        }
    }

    // Hoisted out of `body`: a `+`-joined literal inside a builder
    // is the type-checker shape gui.md warns about.
    private var discordCaption: String {
        L(
            "home.support.discord.caption",
            "Questions, ideas and polls — the discussions that "
                + "shape KiwiDesk."
        )
    }

    private var gitHubCaption: String {
        L(
            "home.support.github.caption",
            "Feature requests, bug reports, source code."
        )
    }

    private var koFiCaption: String {
        L(
            "home.support.kofi.caption",
            "A one-time tip or monthly support, via Ko-fi."
        )
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let mark = BrandAssets.appMark {
                Image(nsImage: mark)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
            }
            Text(L("general.about.app_name", "KiwiDesk"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SettingsTheme.ink)
            Text(L("general.version", "v%1$@", KiwiDeskVersion.semantic))
                .font(.system(size: 12))
                .foregroundStyle(SettingsTheme.ink3)
                .textSelection(.enabled)
            Text("·")
                .font(.system(size: 12))
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
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .linkHover()
        }
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
