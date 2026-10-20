import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Grid's `resize` arm (#763) through the real dispatch: a press
/// moves the edge the focused cell shares with a neighbour, writes
/// the session layer, and cues where a floor stops it. The display,
/// gaps and floor are pinned (#531, #660); the assertions read the
/// `ResizeRefusal` structure, so no locale is pinned (#96).
@Suite("Grid resize (#763)", .serialized)
@MainActor
struct GridResizeTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-grid-resize-\(UUID().uuidString)"
                )
        )
        // 1220 × 820 less 10-pt outer gaps leaves a 1200 × 800
        // grid with 20-pt inner gaps.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1220, height: 820)
        }
        core.tiler.settings.gapsGlobal = Gaps(
            outer: Gaps.Outer(top: 10, bottom: 10, left: 10, right: 10),
            inner: Gaps.Inner(horizontal: 20, vertical: 20)
        )
        #expect(
            core.tiler.settings.minWindowSizes == MinWindowSizes(all: 300)
        )
        core.tiler.animation.isEnabled = false
        return core
    }

    /// `count` windows in a `type` grid capped at `columns` × 1,
    /// window `focus` focused.
    @discardableResult
    private func grid(
        _ core: KiwiCore,
        count: UInt32,
        columns: Int = 3,
        focus: UInt32 = 1,
        type: String = "rigid"
    ) -> SpaceID {
        core.execute("grid.set_type", args: [.string(type)])
        core.execute(
            "grid.set_dimensions",
            args: [.number(Double(columns)), .number(1)]
        )
        for id in 1...count {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(900_000 + Int32(id)),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("grid")]
        )
        core.state.workspaces.focus(WindowID(focus), in: space)
        core.retile()
        return space
    }

    private func refusals(
        _ core: KiwiCore,
        _ body: () -> Void
    ) -> [ResizeRefusal] {
        var seen: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { seen.append($0) }
        body()
        return seen
    }

    private func width(_ core: KiwiCore, _ id: UInt32) -> CGFloat {
        core.tiler.calculatedFrames(state: core.state)[WindowID(id)]?
            .width ?? 0
    }

    @Test("A press grows the focused column against its neighbour")
    func pressMovesTheSharedEdge() {
        let core = makeCore()
        let space = grid(core, count: 3)
        #expect(width(core, 1) == width(core, 2))
        let third = width(core, 3)
        let response = core.execute(
            "resize",
            args: [.string("x"), .number(60)]
        )
        #expect(response.isSuccess)
        #expect(abs(width(core, 1) - (third + 60)) < 0.5)
        #expect(abs(width(core, 2) - (third - 60)) < 0.5)
        // No other track moves.
        #expect(abs(width(core, 3) - third) < 0.5)
        // The session layer took it; the authored list did not.
        #expect(
            core.state.workspaces[space]?.sessionRatios
                .gridColumnWeights != nil
        )
        #expect(core.tiler.settings.grid.columnWeights.isEmpty)
    }

    @Test("A middle column grows at its trailing edge")
    func middleColumnGrowsTrailing() {
        let core = makeCore()
        grid(core, count: 3, focus: 2)
        let third = width(core, 2)
        core.execute("resize", args: [.string("x"), .number(60)])
        #expect(abs(width(core, 2) - (third + 60)) < 0.5)
        #expect(abs(width(core, 3) - (third - 60)) < 0.5)
        #expect(abs(width(core, 1) - third) < 0.5)
    }

    @Test("The last column grows at its leading edge")
    func lastColumnGrowsLeading() {
        let core = makeCore()
        grid(core, count: 3, focus: 3)
        let third = width(core, 3)
        core.execute("resize", args: [.string("x"), .number(60)])
        #expect(abs(width(core, 3) - (third + 60)) < 0.5)
        #expect(abs(width(core, 2) - (third - 60)) < 0.5)
        #expect(abs(width(core, 1) - third) < 0.5)
    }

    @Test("A grow stops at the neighbour's floor and cues it")
    func growStopsAtNeighbourFloor() {
        let core = makeCore()
        grid(core, count: 2, columns: 2)
        let seen = refusals(core) {
            core.execute("resize", args: [.string("x"), .number(500)])
        }
        #expect(abs(width(core, 2) - 300) < 0.5)
        #expect(
            seen == [
                .neighborMinimum(
                    anchor: WindowID(2),
                    focused: WindowID(1),
                    axis: "x",
                    appBound: false
                )
            ]
        )
    }

    /// Five windows in a 3 × 2 grid under `fill_empty_cells`: the
    /// last spans columns 2–3, so a shrink that stops at column 2's
    /// floor names that column's own window, never the spanning
    /// one as "at its minimum" (#1259).
    @Test("A spanning cell's shrink names the column that binds")
    func spanningShrinkNamesTheColumn() {
        let core = makeCore()
        grid(core, count: 5, focus: 5, type: "dynamic")
        core.execute(
            "grid.set_dimensions",
            args: [.number(3), .number(2)]
        )
        core.retile()
        let seen = refusals(core) {
            core.execute("resize", args: [.string("x"), .number(-500)])
        }
        #expect(
            seen == [
                .neighborMinimum(
                    anchor: WindowID(2),
                    focused: WindowID(5),
                    axis: "x",
                    appBound: false
                )
            ]
        )
    }

    /// Four windows in a rigid 2 × 1 grid pile three into column
    /// 2; a shrink there stops at the column's floor and says so
    /// on the pile window pressed.
    @Test("A pile window's shrink cues its own minimum")
    func pileShrinkCues() {
        let core = makeCore()
        grid(core, count: 4, columns: 2, focus: 4)
        let seen = refusals(core) {
            core.execute("resize", args: [.string("x"), .number(-500)])
        }
        #expect(
            seen == [
                .ownMinimum(WindowID(4), axis: "x", appBound: false)
            ]
        )
    }

    @Test("A single row has no edge to move on y")
    func singleRowDividesNothing() {
        let core = makeCore()
        grid(core, count: 3)
        let seen = refusals(core) {
            core.execute("resize", args: [.string("y"), .number(40)])
        }
        #expect(
            seen == [.nothingToDivide(WindowID(1), otherAxisDivides: true)]
        )
    }

    @Test("A write while fewer columns show keeps the rest")
    func sizesSurviveACountDrop() throws {
        let core = makeCore()
        let space = grid(core, count: 3, focus: 2, type: "dynamic")
        // The middle column grows into the third.
        core.execute("resize", args: [.string("x"), .number(60)])
        let first = try #require(
            core.state.workspaces[space]?.sessionRatios
                .gridColumnWeights
        )
        try #require(first.count == 3)
        let third = first[2]
        #expect(third < 1)
        core.state.apply(
            .windowDestroyed(WindowID(3), wasMinimized: false)
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        core.retile()
        // Two columns show; a press there keeps column 3's size.
        core.execute("resize", args: [.string("x"), .number(30)])
        let after =
            core.state.workspaces[space]?.sessionRatios
            .gridColumnWeights
        let kept = try #require(after)
        try #require(kept.count == 3)
        #expect(kept[2] == third)
    }

    @Test("reset_layout_sizing returns to the authored weights")
    func resetDropsTheSession() {
        let core = makeCore()
        let space = grid(core, count: 3)
        core.execute("resize", args: [.string("x"), .number(60)])
        core.execute("reset_layout_sizing", args: [])
        #expect(
            core.state.workspaces[space]?.sessionRatios
                .gridColumnWeights == nil
        )
        #expect(width(core, 1) == width(core, 2))
    }

    /// Two rows: the lower row's top edge is its only inner one,
    /// so a drag naming the other edge moves nothing.
    @Test("A row drag on a leading edge moves that edge")
    func mouseLeadingRowEdge() {
        let core = makeCore()
        let space = grid(core, count: 2, focus: 2)
        core.execute(
            "grid.set_dimensions",
            args: [.number(1), .number(2)]
        )
        core.retile()
        func height(_ id: UInt32) -> CGFloat {
            core.tiler.calculatedFrames(state: core.state)[
                WindowID(id)
            ]?.height ?? 0
        }
        let half = height(2)
        core.applyResizeAdjustment(
            .gridRow(40, leading: true),
            for: WindowID(2),
            in: core.state.workspaces[space]!,
            bounds: CGRect(x: 0, y: 0, width: 1220, height: 820)
        )
        core.retile()
        #expect(abs(height(2) - (half + 40)) < 0.5)
        #expect(abs(height(1) - (half - 40)) < 0.5)
    }

    @Test("A mouse drag on a leading edge moves that edge")
    func mouseLeadingEdge() {
        let core = makeCore()
        let space = grid(core, count: 3, focus: 2)
        let third = width(core, 2)
        core.applyResizeAdjustment(
            .gridColumn(40, leading: true),
            for: WindowID(2),
            in: core.state.workspaces[space]!,
            bounds: CGRect(x: 0, y: 0, width: 1220, height: 820)
        )
        core.retile()
        #expect(abs(width(core, 2) - (third + 40)) < 0.5)
        #expect(abs(width(core, 1) - (third - 40)) < 0.5)
        #expect(abs(width(core, 3) - third) < 0.5)
    }
}
