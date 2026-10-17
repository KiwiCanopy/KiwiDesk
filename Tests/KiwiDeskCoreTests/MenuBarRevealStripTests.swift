import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The #1532 reveal strip's geometry: the band a screen's menu bar
/// reveals from, and which screen's band the pointer is in. Split
/// from `MenuBarRevealReturnTests`.
@Suite("Menu-bar reveal strip (#1532)")
struct MenuBarRevealStripTests {
    // MARK: the strip geometry

    @Test("The band is the deepest of the three readings")
    func bandTakesTheDeepest() {
        #expect(
            GeometryUtils.menuBarBand(
                safeTop: 37,
                reservedTop: 32,
                barHeight: 24
            ) == 37
        )
        #expect(
            GeometryUtils.menuBarBand(
                safeTop: 0,
                reservedTop: 0,
                barHeight: 24
            ) == 24
        )
        // The bare-menu reading (0) never collapses the band.
        #expect(
            GeometryUtils.menuBarBand(
                safeTop: 0,
                reservedTop: 24,
                barHeight: 0
            ) == 24
        )
    }

    @Test("The strip is the top band of the pointer's screen")
    func stripIsTheTopBand() {
        let main = GeometryUtils.MenuBarScreen(
            frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
            band: 37
        )
        let right = GeometryUtils.MenuBarScreen(
            frame: CGRect(x: 1728, y: 0, width: 2560, height: 1440),
            band: 24
        )
        let screens = [main, right]
        // Resting ON the edge reads y == maxY: inside.
        #expect(
            GeometryUtils.pointerInMenuBarStrip(
                CGPoint(x: 864, y: 1117),
                screens: screens
            )
        )
        #expect(
            GeometryUtils.pointerInMenuBarStrip(
                CGPoint(x: 864, y: 1081),
                screens: screens
            )
        )
        #expect(
            !GeometryUtils.pointerInMenuBarStrip(
                CGPoint(x: 864, y: 1079),
                screens: screens
            )
        )
        // The other screen's own band, not the main one's.
        #expect(
            GeometryUtils.pointerInMenuBarStrip(
                CGPoint(x: 3000, y: 1420),
                screens: screens
            )
        )
        #expect(
            !GeometryUtils.pointerInMenuBarStrip(
                CGPoint(x: 3000, y: 1400),
                screens: screens
            )
        )
        // A point on the seam between stacked screens is the
        // upper one's bottom row, not the lower one's strip.
        let lower = GeometryUtils.MenuBarScreen(
            frame: CGRect(x: 0, y: -1000, width: 1728, height: 1000),
            band: 24
        )
        #expect(
            !GeometryUtils.pointerInMenuBarStrip(
                CGPoint(x: 100, y: 0),
                screens: [lower, main]
            )
        )
        // Off every screen: nowhere to reveal.
        #expect(
            !GeometryUtils.pointerInMenuBarStrip(
                CGPoint(x: 5000, y: 10),
                screens: screens
            )
        )
    }
}
