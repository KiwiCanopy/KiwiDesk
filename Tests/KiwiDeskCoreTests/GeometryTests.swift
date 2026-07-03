import CoreGraphics
import Testing

@testable import KiwiDeskCore

@Suite("Menu bar reclaim")
struct MenuBarReclaimTests {
    // Cocoa coordinates: y grows upward, menu bar strip is
    // between visible.maxY and frame.maxY.
    private let frame = CGRect(
        x: 0,
        y: 0,
        width: 1920,
        height: 1080
    )

    @Test("Auto-hidden menu bar strip goes to the windows")
    func reclaimsStrip() {
        let visible = CGRect(
            x: 0,
            y: 0,
            width: 1920,
            height: 1055
        )
        let result = GeometryUtils.reclaimingMenuBar(
            visible,
            screen: frame,
            safeTop: 0
        )
        #expect(result.maxY == frame.maxY)
        #expect(result.minY == visible.minY)
    }

    @Test("The notch housing stays reserved")
    func keepsNotch() {
        let visible = CGRect(
            x: 0,
            y: 0,
            width: 1920,
            height: 1043
        )
        let result = GeometryUtils.reclaimingMenuBar(
            visible,
            screen: frame,
            safeTop: 32
        )
        #expect(result.maxY == frame.maxY - 32)
    }

    @Test("No menu bar inset means no change")
    func secondaryDisplay() {
        // Secondary displays without a menu bar (or with the
        // Dock at the bottom only) have no top inset.
        let visible = CGRect(
            x: 0,
            y: 60,
            width: 1920,
            height: 1020
        )
        let result = GeometryUtils.reclaimingMenuBar(
            visible,
            screen: frame,
            safeTop: 0
        )
        #expect(result == visible)
    }
}
