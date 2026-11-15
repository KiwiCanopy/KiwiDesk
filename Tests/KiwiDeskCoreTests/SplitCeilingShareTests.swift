import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The ceiling slack's share math and its wiring into the issued
/// frames (#3217). The layouts are `SplitCeilingTests` and
/// `SplitCeilingLayoutTests`. Display and `min_window_size`
/// pinned (#531, #660).
@Suite("Split ceiling slack: share and wiring (#3217)", .serialized)
@MainActor
struct SplitCeilingShareTests {
    @Test("A capped span gives its slack to an uncapped one")
    func slackGoesToUncapped() {
        #expect(
            SplitCeiling.share([600, 400], ceilings: [500, nil])
                == [500, 500]
        )
    }

    @Test("A receiver takes only up to its own ceiling")
    func receiverStopsAtCeiling() {
        #expect(
            SplitCeiling.share([600, 400], ceilings: [500, 450])
                == [550, 450]
        )
    }

    @Test("With no receiver nothing moves")
    func noReceiverNothingMoves() {
        #expect(
            SplitCeiling.share([600, 400], ceilings: [500, 400])
                == [600, 400]
        )
        #expect(
            SplitCeiling.share([600, 400], ceilings: [nil, nil])
                == [600, 400]
        )
    }

    @Test("Receivers fill by span, then the open one takes the rest")
    func waterFillsReceivers() {
        let spans = SplitCeiling.share(
            [400, 200, 200],
            ceilings: [100, 250, nil]
        )
        #expect(spans == [100, 250, 450])
        #expect(spans.reduce(0, +) == 800)
    }

    @Test("The issued frames carry the slack; the slots do not")
    func wiredIntoIssuedFrames() throws {
        guard NSScreen.main != nil else { return }
        let directory =
            testTemporaryDirectory
            .appendingPathComponent(
                "kiwidesk-split-ceiling-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        #expect(
            core.tiler.settings.minWindowSizes == MinWindowSizes(all: 300)
        )
        for id in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let w1 = WindowID(1)
        let space = try #require(core.state.workspaces.space(of: w1))
        core.execute("set_mode", args: [.string(space.raw), .string("bsp")])
        // A corroborated 400 pt width ceiling: two distinct asks,
        // each refused twice with the same answer.
        for asked in [700.0, 760.0] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    w1,
                    size: CGSize(width: asked, height: 780)
                )
                core.tiler.boundLearner.observe(
                    w1,
                    currentSize: CGSize(width: 400, height: 780),
                    settledRead: true
                )
            }
        }
        let placed = try #require(
            core.tiler.placedFrames(state: core.state)[w1]
        )
        let slot = try #require(
            core.tiler.calculatedFrames(state: core.state)[w1]
        )
        #expect(abs(placed.width - 400) < 0.01)
        #expect(slot.width > 500)
        // The mouse warp aims at the window where it draws, never
        // at a slot centre sitting past its 400 pt edge.
        let warp = try #require(core.warpFrame(of: w1))
        #expect(abs(warp.width - 400) < 0.01)
        // A press on the edge the window draws reads as a resize
        // gesture, though it sits far inside the slot.
        core.mouse.seedPress(
            at: CGPoint(x: placed.maxX - 2, y: placed.midY)
        )
        core.mouse.seedRelease(at: core.wallClock())
        #expect(core.isResizeGesture(w1))
    }
}
