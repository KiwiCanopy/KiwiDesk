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
///
/// Requires a screen, and says so with a trait rather than an
/// early return: `resizeScrollingSlot` falls back to a
/// 1920x1080 rect when no screen resolves, so headless these
/// would assert against a viewport the fixture never pinned.
/// A SKIP says that; a green would not.
///
/// Main-actor spend is light (tests.md): two windows, a handful
/// of `execute` calls, and one `layoutInput` per `drawnWidth`.
@Suite(
    "Scrolling slot ceiling (#966)",
    .enabled(if: NSScreen.main != nil)
)
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
        along: CGFloat = 1200,
        horizontal: Bool = true
    ) throws -> CGFloat {
        let live = try #require(core.state.workspaces[space])
        return core.tiler.settings.resolvedScrolling(for: live)
            .slotSize
            .editablePoints(
                along: along,
                horizontal: horizontal
            )
    }

    @Test("Growing past the viewport stops at the axis")
    func growStopsAtTheAxis() throws {
        let (core, space) = makeCore()
        let seed = try slotPoints(core, space)
        for _ in 0..<8 {
            #expect(
                core.execute(
                    "resize",
                    args: [.string("x"), .number(400)]
                ).isSuccess
            )
        }
        // Eight 400pt grows would reach ~4300pt unclamped. The
        // store stops at exactly the area the layout draws into,
        // asserted against that area rather than a number.
        // Capping at the raw display bounds instead would bank
        // the outer gaps here; note the bar strip is NOT visible
        // on this axis — `usable` already has the gaps off, and
        // a horizontal bar carves the height, so
        // `verticalCeilingClearsTheBarStrip` is the only net on
        // the strip half.
        #expect(try slotPoints(core, space) == areaExtent(core))
        // ...and it got there by GROWING. Without this a
        // ceiling that binds too low — or a writer that refuses
        // to grow at all — satisfies the line above.
        #expect(try slotPoints(core, space) > seed)
    }

    /// The area the layout has to draw INTO, read off the
    /// engine's own context — independent of what is stored, so
    /// an assertion against it cannot be satisfied by a store
    /// that merely fits. `drawnWidth` below cannot do this job:
    /// it is `min(area, max(stored, floor))`, so comparing the
    /// store to it only ever asks `stored <= area` and a ceiling
    /// binding too LOW passes (code-reviewer, 2026-08-27).
    private func areaExtent(
        _ core: KiwiCore,
        horizontal: Bool = true
    ) throws -> CGFloat {
        let input = try #require(
            core.tiler.layoutInput(state: core.state)
        )
        let context = input.context
        let area = context.scrolling.windowFrame(
            in: context.usable,
            inner: context.gaps.inner,
            global: context.appBarStyle
        )
        return horizontal ? area.width : area.height
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
        // The store sits exactly on the area, which is WHY the
        // next press is visible — an unclamped store would be
        // thousands of points above it.
        #expect(try slotPoints(core, space) == areaExtent(core))
        core.execute(
            "resize",
            args: [.string("x"), .number(-600)]
        )
        #expect(try drawnWidth(core) < before)
    }

    @Test("The vertical ceiling clears the bar on its own axis")
    func verticalCeilingClearsTheBarStrip() throws {
        // The case the rule leads with and no fixture covered
        // (code-reviewer, 2026-08-27): with a vertical scroll
        // axis the App Bar's strip is carved off the SAME axis,
        // so a ceiling taken from the layout region banks the
        // bar's whole thickness rather than the 20pt of outer
        // gaps a horizontal fixture would show.
        let (core, space) = makeCore()
        core.execute(
            "scroll.set_orientation",
            args: [.string("vertical")]
        )
        // Seed BELOW the ceiling first. A vertical `auto` slot
        // resolves against the region and already sits above the
        // drawn area, so without this the clamp fires on the way
        // DOWN and the assertion below passes without a single
        // press having grown anything (guard-prover, 2026-08-27).
        core.execute(
            "scroll.set_slot_size",
            args: [.number(300)]
        )
        let seed = try slotPoints(
            core,
            space,
            along: 800,
            horizontal: false
        )
        for _ in 0..<8 {
            core.execute(
                "resize",
                args: [.string("y"), .number(400)]
            )
        }
        let stored = try slotPoints(
            core,
            space,
            along: 800,
            horizontal: false
        )
        #expect(
            stored == (try areaExtent(core, horizontal: false))
        )
        // ...and it grew to get there.
        #expect(stored > seed)
    }

    @Test("A grow never shrinks a config-set oversize slot")
    func growNeverReducesAConfiguredSlot() throws {
        // `scroll.set_slot_size` is a deliberate statement that
        // has to survive undocking to a narrower screen, which
        // is the whole reason the cap is not in `ScrollSize`.
        // A grow press may refuse to go further; it must not
        // quietly rewrite the value downward, because nothing
        // cues it and the next dock would find it gone.
        let (core, space) = makeCore()
        core.execute(
            "scroll.set_slot_size",
            args: [.number(3000)]
        )
        core.execute(
            "resize",
            args: [.string("x"), .number(400)]
        )
        #expect(try slotPoints(core, space) == 3000)

        // A shrink measures from what is DRAWN (#1057): the
        // first press lands one step below the visible size
        // instead of unwinding invisible points — the store is
        // rewritten only now, the moment the user deliberately
        // resizes on this screen.
        core.execute(
            "resize",
            args: [.string("x"), .number(-400)]
        )
        #expect(
            try slotPoints(core, space) == areaExtent(core) - 400
        )
    }

    @Test("The floor still wins on a display narrower than it")
    func floorOutranksTheCeiling() throws {
        // On a 200pt axis the ceiling would otherwise clamp
        // below the floor #933 exists to hold, so the floor is
        // the one that binds. Pin the default it reasons from
        // (#660) — moving `min_window_size` must red this for a
        // reason, not by coincidence. Seeded AT the floor with
        // a points store: since the never-raise mirror (#1055
        // device QA, 2026-08-28) the floor is capped at the
        // CURRENT size, so what this pins is that a store AT
        // the floor is never pulled below it by the narrow
        // drawn area — not that a smaller store is snapped up.
        let (core, space) = makeCore(width: 200)
        #expect(core.tiler.settings.minWindowSize == 300)
        core.execute(
            "scroll.set_slot_size",
            args: [.number(300)]
        )
        core.execute(
            "resize",
            args: [.string("x"), .number(-400)]
        )
        #expect(try slotPoints(core, space, along: 200) == 300)
    }
}
