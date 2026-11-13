import KiwiDeskCore
import SwiftUI

/// One open of the About sheet; a fresh id per open (#843).
struct AboutRequest: Identifiable {
    let id = UUID()
}

/// About KiwiDesk (#1536): a read-only sheet over Settings — the
/// #859 shape, Return and Escape both dismissing. Holds what Home's
/// footer does not: the wordmark, the version, the update state
/// once more, License, Acknowledgements, the website. A bundled
/// license text opens in a sheet stacked on this one (#3286).
struct AboutSheet: View {
    /// The one update store and the check door, handed in by the
    /// shell — the sheet takes no `SettingsModel` (#859).
    @ObservedObject var store: UpdateStateStore
    let check: () -> Void
    let onDone: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var licenseRequest: LicenseRequest?

    var body: some View {
        VStack(spacing: 12) {
            brand
            versionLine
            UpdateStateRow(store: store, check: check)
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
        .accessibilityLabel(L("home.footer.about", "About KiwiDesk"))
        .sheet(item: $licenseRequest) { request in
            LicenseSheet(request: request) { licenseRequest = nil }
        }
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
        // The version alone; the commit stamp is the CLI's (#1174).
        Text(L("general.version", "v%1$@", KiwiDeskVersion.semantic))
            .font(.system(size: 11))
            .foregroundStyle(SettingsTheme.ink2)
            .textSelection(.enabled)
    }

    private var links: some View {
        HStack(spacing: 16) {
            link(
                L("general.about.license", "License"),
                LicenseDocuments.source(for: .license)
            )
            link(
                L("general.about.acknowledgements", "Acknowledgements"),
                LicenseDocuments.source(for: .acknowledgements)
            )
            link(L("about.website", "Website"), SupportLinks.website)
        }
        .padding(.top, 2)
    }

    /// A bundled text opens in its sheet; without one, the
    /// GitHub copy as a plain link, never an empty sheet.
    @ViewBuilder private func link(
        _ title: String,
        _ source: LicenseDocuments.Source
    ) -> some View {
        switch source {
        case .bundled(let file):
            Button {
                licenseRequest = LicenseDocuments.text(at: file).map {
                    LicenseRequest(title: title, text: $0)
                }
            } label: {
                Text(title).underline()
            }
            .buttonStyle(.plain)
            .linkFace()
        case .link(let url):
            link(title, url)
        }
    }

    private func link(_ title: String, _ url: URL) -> some View {
        // A `Link` is no `Button`, so it cannot take the seal.
        Link(destination: url) { Text(title).underline() }
            .buttonStyle(PlainButtonStyle())
            .linkFace()
    }

    private var doneLabel: String {
        L("common.done", "Done")
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

extension View {
    /// About's link face: an underlined 11 pt link that answers
    /// the pointer, whether it opens a sheet or a URL.
    fileprivate func linkFace() -> some View {
        font(.system(size: 11)).linkHover()
    }
}
