import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let screenA = CGRect(x: 0, y: 0, width: 1920, height: 1080)

/// The four-edge adjacency scan (#878) that decides which
/// scrolling edges are walls. All rects are AX visible frames
/// (y grows downward), matching what the engine feeds it.
@Suite("Screen neighbor detection (#878)")
struct ScreenNeighborsTests {
    @Test("Each side is detected independently")
    func perSideDetection() {
        let right = CGRect(
            x: 1920,
            y: 0,
            width: 1920,
            height: 1080
        )
        let left = CGRect(
            x: -1920,
            y: 0,
            width: 1920,
            height: 1080
        )
        let below = CGRect(
            x: 0,
            y: 1080,
            width: 1920,
            height: 1080
        )
        let above = CGRect(
            x: 0,
            y: -1080,
            width: 1920,
            height: 1080
        )
        #expect(
            ScreenNeighbors.detect(
                around: screenA,
                among: [right]
            ) == ScreenNeighbors(right: true)
        )
        #expect(
            ScreenNeighbors.detect(
                around: screenA,
                among: [left]
            ) == ScreenNeighbors(left: true)
        )
        #expect(
            ScreenNeighbors.detect(
                around: screenA,
                among: [below]
            ) == ScreenNeighbors(bottom: true)
        )
        #expect(
            ScreenNeighbors.detect(
                around: screenA,
                among: [above]
            ) == ScreenNeighbors(top: true)
        )
        #expect(
            ScreenNeighbors.detect(
                around: screenA,
                among: [left, right, above, below]
            )
                == ScreenNeighbors(
                    left: true,
                    right: true,
                    top: true,
                    bottom: true
                )
        )
    }

    @Test("A strictly diagonal screen is no neighbor")
    func diagonalIsNoNeighbor() {
        // Corner-touching only: past the right edge but with no
        // vertical overlap, and past the bottom with no
        // horizontal overlap — an overhang toward either edge
        // would land in void, so neither may become a wall.
        let diagonal = CGRect(
            x: 1920,
            y: 1080,
            width: 1920,
            height: 1080
        )
        #expect(
            ScreenNeighbors.detect(
                around: screenA,
                among: [diagonal]
            ) == ScreenNeighbors()
        )
    }

    @Test("Visible-frame insets don't hide a neighbor")
    func insetNeighborStillDetected() {
        // A neighbor's AX visible frame is inset by its own menu
        // bar, so the rects never touch exactly; the scan's
        // 1 pt slack plus the at-or-past comparison must still
        // see it. (Same slack the stash's #410 corner scan
        // shipped with.)
        let insetRight = CGRect(
            x: 1921,
            y: 25,
            width: 1920,
            height: 1055
        )
        #expect(
            ScreenNeighbors.detect(
                around: screenA,
                among: [insetRight]
            ) == ScreenNeighbors(right: true)
        )
    }

    @Test("The screen itself never counts as its own neighbor")
    func selfIsFiltered() {
        // The engine passes the FULL screen list, own screen
        // included — detect must not read it as a wall on any
        // side.
        let right = CGRect(
            x: 1920,
            y: 0,
            width: 1920,
            height: 1080
        )
        #expect(
            ScreenNeighbors.detect(
                around: screenA,
                among: [screenA, right]
            ) == ScreenNeighbors(right: true)
        )
    }
}

/// The production plumbing that carries the neighbor verdicts
/// into the layout (#878). The layout suites inject
/// `context.screenNeighbors` by hand, so without these a
/// deleted threading line would keep every suite green while
/// every edge silently reverts to open.
@Suite("Screen neighbor plumbing (#878)")
@MainActor
struct ScreenNeighborsPlumbingTests {
    @Test("context(bounds:space:) defaults to every edge open")
    func contextDefaultsOpen() {
        // The single-screen verdict is the default the layout
        // suites reason from — pin it (tests.md: a default other
        // tests reason from owes them a pin).
        let settings = TilingSettings()
        let context = settings.context(
            bounds: screenA,
            space: Space(id: "1", mode: .scrolling),
            sticky: []
        )
        #expect(context.screenNeighbors == ScreenNeighbors())
    }

    @Test("context(bounds:space:) threads the verdicts")
    func contextThreadsNeighbors() {
        let settings = TilingSettings()
        let context = settings.context(
            bounds: screenA,
            space: Space(id: "1", mode: .scrolling),
            sticky: [],
            screenNeighbors: ScreenNeighbors(left: true)
        )
        #expect(
            context.screenNeighbors == ScreenNeighbors(left: true)
        )
    }

    @Test("layoutInput detects from the injected screen list")
    func layoutInputDetectsFromSeams() throws {
        let core = makeTestCore()
        let screen = try #require(
            NSScreen.main ?? NSScreen.screens.first
        )
        core.tiler.visibleBounds = { _ in screenA }
        core.tiler.allScreenBounds = {
            [
                screenA,
                CGRect(x: 1920, y: 0, width: 1920, height: 1080),
            ]
        }
        let input = core.tiler.layoutInput(
            state: core.state,
            space: Space(id: "1", mode: .scrolling),
            screen: screen
        )
        #expect(
            input.context.screenNeighbors
                == ScreenNeighbors(right: true)
        )
    }

    @Test("makeTestCore pins the single-screen verdict")
    func factoryPinsTopology() {
        // The factory neutralizes the live screen-list default
        // so engine fixtures can't inherit the host's
        // arrangement (#523's leak, one hook over) — a suite
        // that wants adjacency injects its own list.
        let core = makeTestCore()
        #expect(core.tiler.allScreenBounds().isEmpty)
    }
}
