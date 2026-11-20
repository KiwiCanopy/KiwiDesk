import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The app strip's window count wears the live shelf's group badge,
/// tinted or not, as the Space Bar's count does (owner, 2026-11-20).
struct KiwiHubBadgeTests {
    private func paint(tinted: Bool) -> KiwiHubPaint {
        var settings = TilingSettings()
        settings.kiwishelf.groupBadgeColor = "#123456"
        settings.kiwishelf.groupBadgeTextColor = "#ABCDEF"
        settings.kiwishelf.tintHubAndPlates = tinted
        settings.kiwishelf.fillColor = "#2C2C2EFF"
        let glass = PanelGlass(settings: settings)
        return KiwiHubPaint.of(
            glass,
            ink: glass.shelf?.panelInk(increaseContrast: false),
            tint: nil,
            increaseContrast: false
        )
    }

    @Test("the count reads the shelf's badge, tinted or not")
    func countReadsTheShelf() {
        for tinted in [false, true] {
            let paint = paint(tinted: tinted)
            #expect(paint.tinted == tinted)
            #expect(paint.badge == Color(kiwiHex: "#123456"), "\(tinted)")
            #expect(
                paint.badgeInk == Color(kiwiHex: "#ABCDEF"),
                "\(tinted)"
            )
        }
    }
}
