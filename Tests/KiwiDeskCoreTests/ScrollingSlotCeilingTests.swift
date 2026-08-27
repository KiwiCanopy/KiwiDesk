import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The scrolling slot is clamped at BOTH ends (#966 device QA).
///
/// `ScrollSize.points(clamping:)` floors a points value and does
/// not cap it, while `ScrollingLayout.metrics` draws
/// `min(along, …)` — so a grow past the viewport inflated the
/// STORED slot while the drawn one stood still, and every
/// invisible step then cost one press on the way back down. The
/// ceiling lives beside the floor in `writeCappedScrollSlot`, so
/// the keyboard verb and the mouse `.scrollWidth` drag inherit
/// it together (#933).
@Suite("Scrolling slot ceiling (#966)")
@MainActor
struct ScrollingSlotCeilingTests {
    /// A scrolling space on a pinned 1200pt-wide display (#531),
    /// focused on the first of two windows.
    private func makeCore(
        width: CGFloat = 1200
    ) -> (core: KiwiCore, space: SpaceID) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-slot-ceiling-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: width, height: 800)
        }
        for id: UInt32 in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("scrolling")]
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        return (core, space)
    }

    private func slotPoints(
        _ core: KiwiCore,
        _ space: SpaceID,
        along: CGFloat = 1200
    ) throws -> CGFloat {
        let live = try #require(core.state.workspaces[space])
        return core.tiler.settings.resolvedScrolling(for: live)
            .slotSize
            .editablePoints(along: along, horizontal: true)
    }

    @Test("Growing past the viewport stops at the axis")
    func growStopsAtTheAxis() throws {
        let (core, space) = makeCore()
        for _ in 0..<8 {
            #expect(
                core.execute(
                    "resize",
                    args: [.string("x"), .number(400)]
                ).isSuccess
            )
        }
        // Eight 400pt grows would reach ~4300pt unclamped; the
        // axis is the ceiling, so the store stops there however
        // many times the key is pressed.
        #expect(try slotPoints(core, space) == 1200)
    }

    /// The width the engine would DRAW for window 1 right now,
    /// read off its own `layoutInput` so the assertion sees what
    /// the layout's `min(along, …)` cap sees rather than the
    /// stored number.
    private func drawnWidth(_ core: KiwiCore) throws -> CGFloat {
        let input = try #require(
            core.tiler.layoutInput(state: core.state)
        )
        let frames = ScrollingLayout().calculateGeometry(
            for: input.tiled,
            in: input.context
        )
        return try #require(frames[WindowID(1)]).width
    }

    @Test("A shrink after a capped grow moves on the first press")
    func shrinkAfterCappedGrowRespondsAtOnce() throws {
        // The symptom the ceiling exists for, asserted on the
        // DRAWN width rather than the stored one: unclamped,
        // those grows banked ~3100pt of invisible slot, so the
        // shrink below stayed above the layout's cap and nothing
        // on screen moved. Asserted as "it changed", never as a
        // number — the drawn width is the axis less this host's
        // gaps and bar strip.
        let (core, space) = makeCore()
        for _ in 0..<8 {
            core.execute(
                "resize",
                args: [.string("x"), .number(400)]
            )
        }
        let before = try drawnWidth(core)
        core.execute(
            "resize",
            args: [.string("x"), .number(-600)]
        )
        #expect(try drawnWidth(core) < before)
        // And the store tracked it, so the next press does too.
        #expect(try slotPoints(core, space) == 600)
    }

    @Test("The floor still wins on a display narrower than it")
    func floorOutranksTheCeiling() throws {
        // `min_window_size` defaults to 300; on a 200pt axis the
        // ceiling would otherwise clamp below the floor #933
        // exists to hold, so the floor is the one that binds.
        let (core, space) = makeCore(width: 200)
        core.execute(
            "resize",
            args: [.string("x"), .number(-400)]
        )
        #expect(try slotPoints(core, space, along: 200) == 300)
    }
}
