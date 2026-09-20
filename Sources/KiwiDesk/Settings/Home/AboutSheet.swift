import KiwiDeskCore
import SwiftUI

/// One open of the About sheet; a fresh id per open (#843).
struct AboutRequest: Identifiable {
    let id = UUID()
}

/// About KiwiDesk (#1536): a read-only sheet over Settings — the
/// #859 shape, Return and Escape both dismissing. Holds what Home's
/// footer does not: the wordmark, the version, the update state
/// once more, Release Notes, License, Acknowledgements, the website.
struct AboutSheet: View {
    @ObservedObject var model: SettingsModel
    let onDone: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            brand
            versionLine
            UpdateStateRow(
                store: model.updater.updates,
                check: { model.updater.checkForUpdates() }
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: SettingsTheme.chipRadius)
                    .fill(SettingsTheme.sunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SettingsTheme.chipRadius)
                    .strokeBorder(SettingsTheme.hairline, lineWidth: 1)
            )
            links
            if let copyright = LicenseDocuments.copyright {
                Text(copyright)
                    .font(.system(size: 10))
                    .foregroundStyle(SettingsTheme.ink3)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }
            Divider()
            HStack {
                Spacer()
                Button(doneLabel, action: onDone)
                    .keyboardShortcut(.defaultAction)
                    .settingsActionButton()
            }
        }
        .padding(EdgeInsets(top: 22, leading: 24, bottom: 18, trailing: 24))
        .frame(width: 420)
        .background(SettingsTheme.card)
        .background(escapeRoute)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("about.title", "About KiwiDesk"))
    }

    @ViewBuilder private var brand: some View {
        if let wordmark {
            Image(nsImage: wordmark)
                .resizable()
                .scaledToFit()
                .frame(height: 104)
                .accessibilityLabel(L("general.about.app_name", "KiwiDesk"))
        } else {
            Text(L("general.about.app_name", "KiwiDesk"))
                .font(.headline)
                .foregroundStyle(SettingsTheme.ink)
        }
    }

    private var wordmark: NSImage? {
        colorScheme == .dark
            ? BrandAssets.wordmarkDark ?? BrandAssets.wordmark
            : BrandAssets.wordmark
    }

    private var versionLine: some View {
        HStack(spacing: 6) {
            Text(L("general.version", "v%1$@", KiwiDeskVersion.semantic))
            if KiwiDeskVersion.commit != "unknown" {
                Text("(\(KiwiDeskVersion.commit))")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(SettingsTheme.ink2)
        .textSelection(.enabled)
    }

    private var links: some View {
        HStack(spacing: 16) {
            link(
                L("general.about.release_notes", "Release Notes"),
                SupportLinks.releases
            )
            link(
                L("general.about.license", "License"),
                LicenseDocuments.url(for: .license)
            )
            link(
                L("general.about.acknowledgements", "Acknowledgements"),
                LicenseDocuments.url(for: .acknowledgements)
            )
            link(L("about.website", "Website"), SupportLinks.website)
        }
        .padding(.top, 2)
    }

    private func link(_ title: String, _ url: URL) -> some View {
        Link(destination: url) { Text(title).underline() }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .linkHover()
    }

    private var doneLabel: String {
        L("presets.layouts.done", "Done")
    }

    /// Escape as a hidden `.cancelAction` button (#859): the sheet
    /// is not a question, so both keys mean "put it away".
    private var escapeRoute: some View {
        Button(doneLabel, action: onDone)
            .keyboardShortcut(.cancelAction)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
    }
}
