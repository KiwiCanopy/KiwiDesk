import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Where a handle's push counts and which way its approach runs
/// (#3349): a push only where the handle's area meets the screen's
/// edge and no screen continues past along the bar's run, the flip
/// of a top or bottom side only, and a side edge's cut at the end
/// its sibling meets.
@Suite("Shelf handle edges (#3349)")
@MainActor
struct ShelfHandleEdgeTests {
    private static let strip = CGRect(
        x: 0,
        y: 760,
        width: 1000,
        height: 40
    )
    private static let screen = CGRect(
        x: 0,
        y: 0,
        width: 1000,
        height: 800
    )

    /// A top handle along x 300–700, its area's screen side at AX
    /// y 0.
    private func spec() -> ShelfHandleSpec {
        ShelfHandleSpec(
            frame: ShelfHandleSpec.frame(
                along: CGRect(x: 300, y: 0, width: 400, height: 30),
                edge: .top,
                side: 0,
                depth: 3
            ),
            edge: .top,
            shown: false,
            reveal: .slide
        )
    }

    /// The target's own push verdict: flush only where the handle's
    /// Along a side edge AX leads from the top, Cocoa from the
    /// A push is a stop against the physical edge: an edge another
    /// A side edge's handle keeps its x through the flip: only a top
    /// The filing hands each bar's run to the neighbour test: a

    /// The target's own push verdict: flush only where the handle's
    /// side is the screen's edge and nothing continues past it.
    @Test("the filed target pushes only at a free screen edge")
    func targetFlush() {
        let primary = GeometryUtils.primaryHeight
        let top = CGRect(x: 0, y: 0, width: 1000, height: primary)
        let below = CGRect(x: 0, y: 0, width: 1000, height: primary + 30)
        let file = { (screen: CGRect, beyond: Bool) in
            KiwiCore.HidingShelves.target(
                self.spec(),
                side: 0,
                strip: Self.strip,
                screen: screen,
                beyond: beyond,
                section: nil,
                cut: (false, false)
            ).flush
        }
        #expect(file(top, false))
        #expect(!file(top, true))
        // A side 30 pt below the screen's top: a menu bar between.
        #expect(!file(below, false))
    }

    /// Along a side edge AX leads from the top, Cocoa from the
    /// bottom: a cut at the lead end trims the approach's top.
    @Test("a side edge's cut trims the end its sibling meets")
    func sideEdgeCut() {
        let run = CGRect(x: 0, y: 300, width: 3, height: 200)
        let whole =
            ShelfRevealer.Target.along(
                run,
                edge: .left,
                side: 0,
                screen: Self.screen
            ).approach ?? .null
        let lead =
            ShelfRevealer.Target.along(
                run,
                edge: .left,
                side: 0,
                screen: Self.screen,
                cut: (true, false)
            ).approach ?? .null
        #expect(whole.maxY == 500 + ShelfReveal.alongReach)
        #expect(lead.maxY == 500)
        #expect(lead.minY == whole.minY)
    }

    /// A push is a stop against the physical edge: an edge another
    /// screen continues past is a crossing (#3349 rule 4).
    @Test("a push counts only where no screen continues past the edge")
    func innerEdgeIsNoPush() {
        let top = ShelfRevealer.Target.along(
            CGRect(x: 300, y: 790, width: 400, height: 3),
            edge: .top,
            side: 800,
            screen: Self.screen
        )
        #expect(top.flush)
        let shared = ShelfRevealer.Target.along(
            CGRect(x: 300, y: 790, width: 400, height: 3),
            edge: .top,
            side: 800,
            screen: Self.screen,
            beyond: true
        )
        #expect(!shared.flush)
        let above = CGRect(x: 0, y: 800, width: 1000, height: 600)
        #expect(
            KiwiCore.HidingShelves.continues(
                .top,
                of: Self.screen,
                along: CGRect(x: 300, y: 790, width: 400, height: 3),
                among: [Self.screen, above]
            )
        )
        #expect(
            !KiwiCore.HidingShelves.continues(
                .bottom,
                of: Self.screen,
                along: CGRect(x: 300, y: 0, width: 400, height: 3),
                among: [Self.screen, above]
            )
        )
        // A side edge judged along the run: a neighbour beside the
        // corner rows alone leaves a mid-edge run free.
        let corner = CGRect(x: -500, y: 0, width: 500, height: 40)
        #expect(
            !KiwiCore.HidingShelves.continues(
                .left,
                of: Self.screen,
                along: CGRect(x: 0, y: 300, width: 3, height: 200),
                among: [Self.screen, corner]
            )
        )
        #expect(
            KiwiCore.HidingShelves.continues(
                .left,
                of: Self.screen,
                along: CGRect(x: 0, y: 20, width: 3, height: 200),
                among: [Self.screen, corner]
            )
        )
    }

    /// A side edge's handle keeps its x through the flip: only a top
    /// or bottom side turns over.
    @Test("a left handle's approach starts at its x, not flipped")
    func leftEdgeSide() {
        let spec = ShelfHandleSpec(
            frame: ShelfHandleSpec.frame(
                along: CGRect(x: 0, y: 300, width: 30, height: 200),
                edge: .left,
                side: 40,
                depth: 3
            ),
            edge: .left,
            shown: false,
            reveal: .slide
        )
        let approach =
            KiwiCore.HidingShelves.target(
                spec,
                side: 40,
                strip: Self.strip,
                screen: Self.screen,
                beyond: false,
                section: nil,
                cut: (false, false)
            ).approach ?? .null
        #expect(approach.minX == 40 - ShelfReveal.overshoot)
        #expect(approach.maxX == 40 + ShelfReveal.approachReach)
    }

    /// The filing hands each bar's run to the neighbour test: a
    /// screen below the run makes its bottom edge a crossing, one
    /// beside only part of the edge leaves the run free.
    @Test(
        "the filing asks the neighbour test along each bar's run",
        .enabled(if: NSScreen.screens.first != nil)
    )
    func filingAsksTheNeighbours() throws {
        let screen = try #require(NSScreen.screens.first)
        let frame = screen.frame
        let ax = GeometryUtils.flip(
            frame,
            primaryHeight: GeometryUtils.primaryHeight
        )
        // The run sits mid-edge, clear of the corner neighbour.
        var shelf = KiwiShelf()
        shelf.alignment = .center
        let plan = KiwiCore.ShelfPlan(
            edge: .bottom,
            strip: CGRect(
                x: ax.minX,
                y: ax.maxY - 30,
                width: ax.width,
                height: 30
            ),
            horizontal: true,
            arrangement: ShelfArrangement.arrange(
                length: ax.width,
                spaceNeed: 200,
                appNeed: nil,
                spaceFloor: 0,
                shelf: shelf,
                pocket: nil
            ),
            shelfEdge: ShelfEdge(
                .bottom,
                reserves: true,
                bars: [.space: .auto]
            ),
            needs: [.space: 200]
        )
        let flush = { (screens: [CGRect]) -> Bool? in
            var hiding = KiwiCore.HidingShelves()
            hiding.file(
                [plan],
                display: DisplayID(1),
                screen: screen,
                items: nil,
                screens: screens,
                reveal: ShelfRevealer(),
                hover: [],
                settings: TilingSettings()
            )
            return hiding.targets.values.first?.flush
        }
        let below = CGRect(
            x: frame.minX,
            y: frame.minY - 500,
            width: frame.width,
            height: 500
        )
        let corner = CGRect(
            x: frame.minX,
            y: frame.minY - 500,
            width: 40,
            height: 500
        )
        #expect(flush([frame]) == true)
        #expect(flush([frame, below]) == false)
        #expect(flush([frame, corner]) == true)
    }
}
