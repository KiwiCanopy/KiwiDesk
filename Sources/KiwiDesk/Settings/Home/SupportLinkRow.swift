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
                BrandMark(image: mark).padding(.top, 2)
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

/// A service's mark as KiwiDesk draws it wherever a link names that
/// service (#1536, #1863): the template image in secondary ink,
/// decorative — the link's text is its label.
struct BrandMark: View {
    let image: NSImage
    var side: CGFloat = 16

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
            .foregroundStyle(SettingsTheme.ink2)
            .accessibilityHidden(true)
    }
}
