import AppKit
import KiwiDeskCore
import SwiftUI

/// Embedded documentation link component (#1019, `SupportLinks`).
struct GuideLink: View {
    /// Font point size and ink color for link prose (`LinkedCaption`).
    var pointSize: CGFloat = NSFont.preferredFont(
        forTextStyle: .caption1
    ).pointSize
    var ink: Color = Color(nsColor: .secondaryLabelColor)

    var body: some View {
        let parts = LinkedCaption.split(frame: Self.prose)
        LinkedCaption(
            leading: parts.0,
            linkTitle: Self.label,
            trailing: parts.1,
            navigate: Self.open,
            pointSize: pointSize,
            ink: NSColor(ink)
        )
    }

    /// The sentence template carrying guide link title (owner 2026-08-26).
    @MainActor static var prose: String {
        L(
            "common.guide_hint",
            "Want to get more out of it? Read %1$@."
        )
    }

    /// Localized guide link label (`.claude/rules/localization.md`).
    @MainActor static var label: String {
        L("common.read_guide", "the guide")
    }

    /// Opens user guide in default browser (`SupportLinks.guide`,
    /// `GuideLinkSurfaceTests`).
    @MainActor static func open() {
        NSWorkspace.shared.open(SupportLinks.guide)
    }
}
