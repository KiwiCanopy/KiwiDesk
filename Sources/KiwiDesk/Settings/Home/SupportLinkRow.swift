import AppKit
import SwiftUI

/// One link of Home's support strip (#1536): the service's mark in
/// secondary ink, an underlined title that opens the URL, one line
/// of what it is.
struct SupportLinkRow: View {
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
                    .frame(width: 16, height: 16)
                    .foregroundStyle(SettingsTheme.ink2)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Link(destination: url) {
                    Text(title).underline()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .linkHover()
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(SettingsTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: 320, alignment: .leading)
    }
}
