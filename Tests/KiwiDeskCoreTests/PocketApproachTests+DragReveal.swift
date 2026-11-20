import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// With `kiwishelf.pocket_drag_reveal` off, a window drag holds the
/// handle's approach down: no rise, no progress fill, no risen pocket
/// (#3522). An extension of this suite for its rig.
extension PocketApproachTests {
    @Test("off, a drag holds the handle's approach down")
    func dragHoldsTheApproachDown() throws {
        let rig = try rig()
        defer { BarMotion.reducedOverride = nil }
        rig.core.execute(
            "kiwishelf.set_pocket_drag_reveal",
            args: [.bool(false)]
        )
        let target = try #require(rig.target)
        // Control: with no drag, the approach still runs its rise.
        rig.move(to: try nearTab(target))
        #expect(rig.spec?.rise != nil)
        rig.move(to: CGPoint(x: -10_000, y: -10_000))
        rig.timers.fireAll()
        rig.pass()
        rig.core.pocketPlate.dragging = WindowID(7)
        rig.move(to: try nearTab(target))
        try #require(rig.core.shelves.reveal.fills[rig.key] != nil)
        let held = try #require(rig.spec)
        #expect(held.rise == nil)
        #expect(held.tabFill == nil)
        #expect(!held.risen)
        rig.timers.fireAll()
        rig.pass()
        #expect(rig.spec?.risen == false)
    }
}
