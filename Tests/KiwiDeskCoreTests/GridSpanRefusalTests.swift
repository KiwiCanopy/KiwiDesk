import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Grid's refusal where the focused cell already spans the pressed
/// axis (#2707): a grow meets the tiling area's edge, a shrink finds
/// no other row or column to take the space. Uses `GridResizeTests`'
/// pinned display, gaps and floor.
@Suite("Grid span refusal (#2707)", .serialized)
@MainActor
struct GridSpanRefusalTests {
    private let host = GridResizeTests()

    /// A single row fills the height (#2707): a grow meets the
    /// area's edge, a shrink finds no other row to take the height.
    @Test("A single row has no edge to move on y")
    func singleRowSpansTheHeight() {
        let core = host.makeCore()
        host.grid(core, count: 3)
        let seen = host.refusals(core) {
            core.execute("resize", args: [.string("y"), .number(40)])
            core.execute("resize", args: [.string("y"), .number(-40)])
        }
        #expect(
            seen == [
                .ownMaximum(WindowID(1), axis: "y", atBoundary: true),
                .gridNoOtherTrack(WindowID(1), axis: "y"),
            ]
        )
    }

    /// A lone cell fills both axes (#2707).
    @Test("A lone cell's shrink names the missing column")
    func loneCellHasNoOtherTrack() {
        let core = host.makeCore()
        // Dynamic: a rigid grid keeps its empty cells beside it.
        host.grid(core, count: 1, type: "dynamic")
        let seen = host.refusals(core) {
            core.execute("resize", args: [.string("x"), .number(40)])
            core.execute("resize", args: [.string("x"), .number(-40)])
        }
        #expect(
            seen == [
                .ownMaximum(WindowID(1), axis: "x", atBoundary: true),
                .gridNoOtherTrack(WindowID(1), axis: "x"),
            ]
        )
    }

    /// A screen under the 300-pt floor piles even one cell, so no
    /// track divides on either axis (#2707).
    @Test("A piled grid refuses by direction")
    func pileRefusesByDirection() {
        let core = host.makeCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 280, height: 280)
        }
        host.grid(core, count: 3)
        let seen = host.refusals(core) {
            core.execute("resize", args: [.string("x"), .number(40)])
            core.execute("resize", args: [.string("x"), .number(-40)])
        }
        #expect(
            seen == [
                .ownMaximum(WindowID(1), axis: "x", atBoundary: true),
                .gridNoOtherTrack(WindowID(1), axis: "x"),
            ]
        )
    }
}
