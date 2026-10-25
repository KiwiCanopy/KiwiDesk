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
/// injected closure is never consulted — hence each test's
/// guard. Only bounds are pinned, never topology.
///
/// The resize half of the seam lives in
/// `VisibleBoundsResizeSeamTests`.
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
        let dir =
            testTemporaryDirectory
            .appendingPathComponent(
                "kiwidesk-bounds-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: dir)
        core.tiler.visibleBounds = { _ in bounds }
        // Zero gaps and no bar, so the injected rect IS the
        // layout rect: the shelf's reservation is a real default
        // with its own coverage, taken in every layout while any
        // bar can show (#1517), and leaving it on here would
        // only blur what these assertions are about.
        core.execute("set_gap_global", args: [.number(0)])
        for verb in [
            "space_bar.set_visibility",
            "monocle.set_app_bar_visibility",
            "scroll.set_app_bar_visibility",
        ] {
            core.execute(verb, args: [.string("hidden")])
        }
        #expect(core.tiler.settings.spaceBarStyle.visibility == .hidden)
        #expect(!core.tiler.settings.anyAppBarCanShow)
        // Pin the default this fixture reasons from, the rule
        // this change set wrote into §5: the pile threshold
        // below is 2 * min.
        #expect(core.tiler.settings.minWindowSizes == MinWindowSizes(all: 300))
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

    @Test("A rect below 2 * min_window_size scrolls the pair")
    func narrowBoundsScrollThePair() {
        // No screen at all means the injected closure is
        // never consulted (the layout resolves no screen to
        // pass it), so there is nothing here to assert.
        guard NSScreen.main != nil else { return }
        // 500pt cannot seat two 300pt regions side by side, so
        // BspLayout scrolls them (#2542): the focused window takes
        // the whole width and the other parks at the hide corner
        // — the shape a narrow CI display produces by accident
        // (#523).
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
        // One shows across the whole width; the other parks at
        // the real screen's corner, off the pinned rect but for
        // the peek.
        let inside = CGRect(x: 0, y: 0, width: 500, height: 900)
            .insetBy(dx: 2, dy: 2)
        let shown = [first, second].filter { inside.intersects($0) }
        #expect(shown.count == 1)
        #expect(shown.allSatisfy { abs($0.width - 500) < 1 })
    }
}
