import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Hover focus on a sticky traveler (#1869): the probe writes the
/// focus where `focusWindow` does — the traveler's HOME Space — so
/// a scrolling row it is drawn in re-seats on it and the hover
/// stands down, as for any member.
@Suite("Hover focus on a sticky traveler (#1869)", .serialized)
@MainActor
struct HoverFocusTravelerTests {
    @Test("A traveler whose focus re-seats the row stands down")
    func travelerReseatStandsDown() throws {
        let directory =
            testTemporaryDirectory
            .appendingPathComponent("kiwidesk-hover-\(UUID().uuidString)")
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(1), pid: 11, appName: "T")
            )
        )
        core.focusWindow(WindowID(1), warp: false)
        #expect(core.execute("make_sticky", args: []).isSuccess)
        core.execute("focus_space", args: [.string("2")])
        let space = try #require(core.activeSpace?.id)
        try #require(space.raw == "2")
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(3), pid: 13, appName: "M")
            )
        )
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("scrolling")]
        )
        core.execute("scroll.set_slot_size", args: [.number(700)])
        core.execute("scroll.set_anchor", args: [.string("center")])
        core.focusWindow(WindowID(3), warp: false)
        let placed = core.tiler.placedFrames(state: core.state)
        let traveler = try #require(placed[WindowID(1)])
        for (id, frame) in placed {
            core.state.apply(.windowMoved(id, frame))
        }
        core.frontStack = {
            placed.map {
                listed(
                    number: Int($0.key.raw),
                    pid: 10 + pid_t($0.key.raw),
                    frame: $0.value
                )
            }
        }
        core.tiler.settings.mouse.hoverFocus = true
        core.frontmostPIDProvider = { 13 }
        let shown = traveler.intersection(
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        )
        try #require(!shown.isEmpty)
        #expect(
            core.hoverTarget(at: CGPoint(x: shown.midX, y: shown.midY))
                == nil
        )
    }
}

/// One front-to-back row (#1869); the fields a fixture leaves out
/// are the defaults no stand-down reads.
private func listed(
    number: Int = 0,
    pid: pid_t = 0,
    layer: Int = 0,
    frame: CGRect
) -> KiwiCore.FrontWindow {
    KiwiCore.FrontWindow(
        number: CGWindowID(number),
        pid: pid,
        layer: layer,
        frame: frame
    )
}
