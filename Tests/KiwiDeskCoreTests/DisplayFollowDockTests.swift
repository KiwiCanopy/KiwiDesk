import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The #446 display follow's Dock stand-down: an auto-hidden Dock
/// reserves no visible frame, so a click on it read as a desktop
/// click and moved the focused display to the Dock's screen while
/// macOS kept the clicked app in front. Main-actor spend: pure
/// predicate calls, no AppKit.
@Suite("Display follow stands down on the Dock")
@MainActor
struct DisplayFollowDockTests {
    private let dock = Int(CGWindowLevelForKey(.dockWindow))
    private let press = CGPoint(x: 800, y: 1080)

    private func window(
        layer: Int,
        frame: CGRect = CGRect(x: 0, y: 1040, width: 1728, height: 77)
    ) -> KiwiCore.FrontWindow {
        KiwiCore.FrontWindow(
            number: 7,
            pid: 4242,
            layer: layer,
            frame: frame,
            owner: "Dock"
        )
    }

    @Test("A press on the Dock's window is a Dock press")
    func dockIsHit() {
        #expect(
            KiwiCore.pressHitsDock(at: press, in: [window(layer: dock)])
        )
    }

    @Test("A press on a normal window is not")
    func normalWindowIsNot() {
        #expect(
            !KiwiCore.pressHitsDock(at: press, in: [window(layer: 0)])
        )
    }

    @Test("A press beside the Dock's window is not")
    func pressOutsideIsNot() {
        #expect(
            !KiwiCore.pressHitsDock(
                at: CGPoint(x: 800, y: 500),
                in: [window(layer: dock)]
            )
        )
    }

    @Test("The front window decides, not one behind it")
    func frontWindowDecides() {
        #expect(
            !KiwiCore.pressHitsDock(
                at: press,
                in: [window(layer: 0), window(layer: dock)]
            )
        )
    }

    @Test("An empty desktop is not the Dock")
    func emptyDesktopIsNot() {
        #expect(!KiwiCore.pressHitsDock(at: press, in: []))
    }
}
