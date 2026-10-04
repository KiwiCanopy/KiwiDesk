import AppKit
import Testing

@testable import KiwiDeskCore

/// The focus ring hides in Mission Control (#1917): macOS 27 draws
/// a raw SkyLight window over the overview at its desktop frame,
/// so every production ring, in either draw order, is the AppKit
/// panel whose `.transient` behavior hides it.
@Suite("Border ring in Mission Control")
@MainActor
struct BorderMissionControlTests {
    @Test(
        "Every draw order builds a transient AppKit ring",
        arguments: [BorderGeometry.Order.below, .above]
    )
    func ringIsTransientPanel(order: BorderGeometry.Order) throws {
        let overlay = BorderOverlay(window: 7, order: order)
        let panel = try #require(
            overlay.backend as? AppKitBorderOverlay
        )
        #expect(panel.orderMode == order)
        overlay.update(
            frame: CGRect(x: -9_000, y: -9_000, width: 40, height: 30),
            width: 4,
            cornerStyle: .rounded,
            cornerRadius: 16,
            colorHex: "#FF0000",
            screen: nil,
            room: nil
        )
        defer { overlay.hide() }
        let behavior = try #require(panel.panelBehavior)
        #expect(behavior.contains(.transient))
    }
}
