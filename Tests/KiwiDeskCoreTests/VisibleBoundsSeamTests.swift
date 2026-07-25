import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `TilingEngine.visibleBounds` is the one place display *size*
/// enters layout (#531). These pin that: with it injected, what
/// the layout builds is a function of the fixture's rect alone,
/// so a suite can no longer assert an arrangement the host
/// display secretly decided.
///
/// Screen *existence* is still the host's: `screen(for:in:)`
/// falls back to `NSScreen.main`, and with no screen at all the
/// injected closure is never consulted — hence the guard in
/// `makeCore`. Only bounds are pinned, never topology.
@Suite("Injected visible bounds (#531)", .serialized)
@MainActor
struct VisibleBoundsSeamTests {
    /// Deliberately a shape no real display has: if any layout
    /// path still read the host's screen, every assertion below
    /// would miss by hundreds of points rather than passing for
    /// the wrong reason.
    private static let display = CGRect(
        x: 40,
        y: 60,
        width: 1234,
        height: 987
    )

    private func makeCore(
        bounds: CGRect = VisibleBoundsSeamTests.display
    ) -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-bounds-\(UUID().uuidString)"
            )
        let core = KiwiCore(configDirectory: dir)
        core.tiler.visibleBounds = { _ in bounds }
        // Zero gaps and no Space Bar, so the injected rect IS
        // the layout rect: the reservations are real defaults
        // (a 32pt left strip) with their own coverage, and
        // leaving them on here would only blur what these
        // assertions are about.
        core.execute("set_gap_global", args: [.number(0)])
        core.execute(
            "space_bar.set_enabled",
            args: [.bool(false)]
        )
        return core
    }

    private func spawn(_ core: KiwiCore, count: Int) {
        for index in 1...count {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(index)),
                        pid: 1,
                        appName: "A"
                    )
                )
            )
        }
    }

    @Test("A lone window fills exactly the injected rect")
    func loneWindowFillsInjectedBounds() {
        // No screen at all means the injected closure is
        // never consulted (the layout resolves no screen to
        // pass it), so there is nothing here to assert.
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        spawn(core, count: 1)
        let frames = core.tiler.calculatedFrames(
            state: core.state
        )
        #expect(frames[WindowID(1)] == Self.display)
    }

    @Test("The split lands at the injected rect's midpoint")
    func splitFollowsInjectedWidth() {
        // No screen at all means the injected closure is
        // never consulted (the layout resolves no screen to
        // pass it), so there is nothing here to assert.
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("bsp")]
        )
        core.execute(
            "bsp.set_strategy",
            args: [.string("alternating")]
        )
        spawn(core, count: 2)
        let frames = core.tiler.calculatedFrames(
            state: core.state
        )
        let left = frames[WindowID(1)]!
        let right = frames[WindowID(2)]!
        // Halves of 1234, not of whatever the host is wide.
        #expect(abs(left.width - 617) < 1)
        #expect(abs(right.width - 617) < 1)
        #expect(abs(left.minX - 40) < 1)
        #expect(abs(right.minX - 657) < 1)
    }

    @Test("A rect below 2 * min_window_size piles instead")
    func narrowBoundsPileThePair() {
        // No screen at all means the injected closure is
        // never consulted (the layout resolves no screen to
        // pass it), so there is nothing here to assert.
        guard NSScreen.main != nil else { return }
        // 500pt cannot seat two 300pt regions side by side, so
        // BspLayout falls back to an OverlapStack cascade
        // (#383/#44) — the failure mode a narrow CI display used
        // to produce by accident (#523). Its signature is equal
        // minX with midYs exactly `OverlapStack.offset` (40pt,
        // vertical-only) apart.
        let core = makeCore(
            bounds: CGRect(x: 0, y: 0, width: 500, height: 900)
        )
        core.execute(
            "set_mode",
            args: [.string("1"), .string("bsp")]
        )
        core.execute(
            "bsp.set_strategy",
            args: [.string("alternating")]
        )
        spawn(core, count: 2)
        let frames = core.tiler.calculatedFrames(
            state: core.state
        )
        let first = frames[WindowID(1)]!
        let second = frames[WindowID(2)]!
        #expect(abs(first.minX - second.minX) < 1)
        #expect(
            abs(
                abs(first.midY - second.midY)
                    - OverlapStack.offset
            ) < 1
        )
    }

    @Test("The BSP resize sign reads the injected bounds")
    func bspFocusSignFollowsInjectedBounds() {
        // `bspFocusSign` classifies the focused slot as the first
        // or second region by comparing it against the display
        // bounds, so an un-injected read would compare a slot laid
        // out in the fixture's 1000pt rect against the host's much
        // wider one — and on a wide host BOTH windows fall in its
        // first half, so the right window's delta would stop
        // flipping. Growing the right window must lower the shared
        // ratio (#122).
        guard NSScreen.main != nil else { return }
        let core = makeCore(
            bounds: CGRect(x: 0, y: 0, width: 1000, height: 900)
        )
        core.execute(
            "set_mode",
            args: [.string("1"), .string("bsp")]
        )
        core.execute(
            "bsp.set_strategy",
            args: [.string("alternating")]
        )
        spawn(core, count: 2)
        core.state.apply(.windowFocused(WindowID(2)))
        let before = core.tiler.settings.resolvedBsp(
            for: core.state.workspaces[SpaceID("1")]!
        ).splitRatioH
        core.execute("resize", args: [.string("x"), .number(100)])
        let after = core.tiler.settings.resolvedBsp(
            for: core.state.workspaces[SpaceID("1")]!
        ).splitRatioH
        #expect(abs((before - after) - 0.1) < 1e-9)
    }

    @Test("A finished mouse resize reads the injected bounds")
    func mouseResizeEndFollowsInjectedBounds() {
        // `handleResizeEnd` translates the dragged frame into a
        // ratio delta against the display bounds, so the stored
        // ratio is delta-over-span for the INJECTED span: dragging
        // the left window's right edge 100pt wider on a 1000pt
        // display is +0.1, whatever the host measures.
        guard NSScreen.main != nil else { return }
        let core = makeCore(
            bounds: CGRect(x: 0, y: 0, width: 1000, height: 900)
        )
        core.execute(
            "set_mode",
            args: [.string("1"), .string("bsp")]
        )
        core.execute(
            "bsp.set_strategy",
            args: [.string("alternating")]
        )
        spawn(core, count: 2)
        guard let space = core.state.workspaces[SpaceID("1")],
            let slot = core.tiler.calculatedFrames(
                state: core.state
            )[WindowID(1)]
        else {
            Issue.record("no slot for the left window")
            return
        }
        let before = core.tiler.settings.resolvedBsp(
            for: space
        ).splitRatioH
        var dragged = slot
        dragged.size.width += 100
        core.handleResizeEnd(
            WindowID(1),
            slot: slot,
            frame: dragged,
            in: space
        )
        let after = core.tiler.settings.resolvedBsp(
            for: core.state.workspaces[SpaceID("1")]!
        ).splitRatioH
        #expect(abs((after - before) - 0.1) < 1e-9)
    }

    @Test("The resize span is the injected width, not the host's")
    func resizeSpanFollowsInjectedWidth() {
        // No screen at all means the injected closure is
        // never consulted (the layout resolves no screen to
        // pass it), so there is nothing here to assert.
        guard NSScreen.main != nil else { return }
        // A 1000pt-wide display makes the keyboard resize's
        // delta-over-span arithmetic exact: 100pt of a 1000pt
        // span is 0.1 of the ratio, whatever the host measures.
        let core = makeCore(
            bounds: CGRect(x: 0, y: 0, width: 1000, height: 900)
        )
        core.execute(
            "set_mode",
            args: [.string("1"), .string("bsp")]
        )
        core.execute(
            "bsp.set_strategy",
            args: [.string("alternating")]
        )
        spawn(core, count: 2)
        core.state.apply(.windowFocused(WindowID(1)))
        let before = core.tiler.settings.resolvedBsp(
            for: core.state.workspaces[SpaceID("1")]!
        ).splitRatioH
        core.execute("resize", args: [.string("x"), .number(100)])
        let after = core.tiler.settings.resolvedBsp(
            for: core.state.workspaces[SpaceID("1")]!
        ).splitRatioH
        #expect(abs((after - before) - 0.1) < 1e-9)
    }
}
