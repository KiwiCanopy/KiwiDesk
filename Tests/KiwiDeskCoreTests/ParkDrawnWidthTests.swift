import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A bottom-left park anchors the window's right edge, so it is
/// laid at the width the window draws now when that is wider than
/// the ask, and the first park leaves the peek before the learner
/// knows the app's minimum (#2759). The right corner's x is
/// width-free and passes unchanged.
@Suite("Bottom-left park at the drawn width (#2759)", .serialized)
@MainActor
struct ParkDrawnWidthTests {
    /// A screen with a neighbour on its right parks bottom-left.
    private static let screen = CGRect(
        x: 0,
        y: 25,
        width: 1440,
        height: 800
    )
    private static let right = CGRect(
        x: 1440,
        y: 25,
        width: 1440,
        height: 800
    )

    private func park(
        width: CGFloat,
        corner: TilingEngine.HideCorner
    ) -> CGRect {
        TilingEngine.stashFrame(
            CGRect(x: 0, y: 0, width: width, height: 324),
            in: Self.screen,
            corner: corner
        )
    }

    @Test("A wider drawn width moves the left park's x")
    func widerDrawnWidthReanchors() {
        let asked = park(width: 336, corner: .bottomLeft)
        let drawn = CGRect(x: 200, y: 300, width: 500, height: 375)
        let issued = TilingEngine.parkAtDrawnWidth(
            asked,
            drawn: drawn,
            in: Self.screen
        )
        #expect(issued == park(width: 500, corner: .bottomLeft))
        #expect(issued.maxX - Self.screen.minX == TilingEngine.stashPeekX)
    }

    @Test("A narrower drawn width keeps the ask")
    func narrowerDrawnWidthKeeps() {
        let asked = park(width: 500, corner: .bottomLeft)
        let drawn = CGRect(x: 200, y: 300, width: 336, height: 375)
        #expect(
            TilingEngine.parkAtDrawnWidth(
                asked,
                drawn: drawn,
                in: Self.screen
            ) == asked
        )
    }

    @Test("The right corner and a shown frame pass unchanged")
    func otherFramesPass() {
        let drawn = CGRect(x: 200, y: 300, width: 900, height: 375)
        let rightPark = park(width: 336, corner: .bottomRight)
        let slot = CGRect(x: 100, y: 100, width: 336, height: 300)
        for frame in [rightPark, slot] {
            #expect(
                TilingEngine.parkAtDrawnWidth(
                    frame,
                    drawn: drawn,
                    in: Self.screen
                ) == frame
            )
        }
    }

    /// Six windows in a stack Space on the left screen, each drawn
    /// 700 wide before any ask: the run parks 2…4, and every park
    /// the loop sends leaves one peek at the drawn width.
    @Test("The layout loop sends the left park at the drawn width")
    func loopSendsTheDrawnWidth() throws {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-park-drawn-\(UUID().uuidString)"
                )
        )
        // Pinned (tests.md, #531); the right neighbour picks the
        // bottom-left corner.
        core.tiler.visibleBounds = { _ in Self.screen }
        core.tiler.allScreenBounds = { [Self.screen, Self.right] }
        for id in 1...6 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(910_000 + id),
                        appName: "App\(id)",
                        frame: CGRect(x: 100, y: 100, width: 700, height: 400)
                    )
                )
            )
        }
        let space = try #require(
            core.state.workspaces.space(of: WindowID(1))
        )
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("stack")]
        )
        _ = core.execute("set_min_window_size", args: [.number(300)])
        core.state.workspaces.focus(WindowID(6), in: space)
        core.retile(animated: false)
        let cover = try #require(core.tiler.runCovers[space])
        #expect(!cover.behind.isEmpty)
        // The issued set names the park the retile sent, so a
        // reader of where a window is agrees with it.
        let issued = core.tiler.placedFrames(state: core.state)
        for id in cover.behind.keys {
            let sent = try #require(core.tiler.commandedFrame(of: id))
            #expect(issued[id] == sent)
            #expect(core.tiler.looksStashed(sent))
            #expect(sent.width == 700)
            #expect(sent.maxX - Self.screen.minX == TilingEngine.stashPeekX)
        }
    }
}
