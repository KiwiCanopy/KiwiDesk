import CoreGraphics
import Testing

@testable import KiwiDeskCore

// Single 1920×1080 display, Cocoa coordinates; visibleFrame
// excludes the 25-pt menu bar strip.
private let displayFrame = CGRect(
    x: 0,
    y: 0,
    width: 1920,
    height: 1080
)
private let cocoaVisible = CGRect(
    x: 0,
    y: 0,
    width: 1920,
    height: 1055
)
private let primaryH: CGFloat = 1080

private func makeState() -> StateCoordinator {
    var s = StateCoordinator(defaultSpace: SpaceID(1))
    s.workspaces.upsertDisplay(
        Display(
            id: DisplayID(1),
            name: "Main",
            frame: displayFrame,
            visibleFrame: cocoaVisible
        )
    )
    s.workspaces.assign(SpaceID(1), to: DisplayID(1))
    return s
}

private func addWindows(
    _ state: inout StateCoordinator,
    _ ids: [UInt32]
) {
    for id in ids {
        state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(id),
                    pid: 99,
                    appName: "TestApp",
                    title: "",
                    frame: CGRect(
                        x: 0,
                        y: 0,
                        width: 800,
                        height: 600
                    )
                )
            )
        )
    }
}

/// The frontmost app's key window is placed LAST in its display's
/// list, so the quit grid gives it the slot where being in front is
/// correct (#688).
///
/// Nothing can raise a window above that one — measured, see
/// `raiseFloor` — so the circle cannot put anything over it. Before
/// this, it kept whatever slot the space walk gave it and covered
/// the pile-mates the circle wanted above it: the single
/// wrong-looking window in an otherwise correct quit grid (owner
/// device QA, 2026-08-03). Last in the list is last in its cell's
/// cascade, which is the slot `QuitGridLayout.raiseOrder` raises
/// last and therefore intends to be frontmost.
@Suite("WindowGather — the frontmost window's slot (#688)")
struct GatherWindowsFrontmostTests {

    private func ids(_ raw: [UInt32]) -> [WindowID] {
        raw.map(WindowID.init)
    }

    @Test("The frontmost window is moved to the end")
    func frontmostWindowGoesLast() throws {
        var state = makeState()
        addWindows(&state, [1, 2, 3, 4])
        let groups = WindowGather.collect(
            state: state,
            primaryHeight: primaryH,
            placingLast: WindowID(2)
        )
        let group = try #require(groups.first)
        #expect(group.windows == ids([1, 3, 4, 2]))
    }

    /// It is a MOVE, not a copy or an append: the window must not
    /// end up in the grid twice, which would give one window two
    /// frames and let the circle raise it twice — the focus slide
    /// `ZOrderDrain` refuses by construction.
    @Test("Placing last moves the window rather than duplicating it")
    func frontmostWindowIsNotDuplicated() throws {
        var state = makeState()
        addWindows(&state, [1, 2, 3])
        let groups = WindowGather.collect(
            state: state,
            primaryHeight: primaryH,
            placingLast: WindowID(1)
        )
        let group = try #require(groups.first)
        #expect(group.windows.count == 3)
        #expect(Set(group.windows).count == 3)
        #expect(group.windows.last == WindowID(1))
    }

    /// Nil, and an id that is not on this display or not managed at
    /// all, all leave the order exactly as the space walk built it.
    /// Nil is the ordinary answer at quit — no frontmost app, an
    /// ignored panel (#21), or an AX read that did not come back.
    @Test("An absent frontmost window leaves the order untouched")
    func unknownOrNilFrontmostChangesNothing() throws {
        var state = makeState()
        addWindows(&state, [1, 2, 3])
        for candidate in [nil, WindowID(99)] {
            let groups = WindowGather.collect(
                state: state,
                primaryHeight: primaryH,
                placingLast: candidate
            )
            let group = try #require(groups.first)
            #expect(group.windows == ids([1, 2, 3]))
        }
    }

    /// The whole point: the window the grid placed last is raised
    /// after every window it can overlap, so "it ends up in front"
    /// IS the arrangement rather than a departure from it.
    ///
    /// The property is per-CELL, not per-display, and the
    /// difference is real: cells are disjoint rectangles, so the
    /// only windows this one can cover are its own cell-mates.
    /// Round-robin means last-in-list is the deepest slot of
    /// whichever cell index `n - 1` falls in, and that is the last
    /// of its bucket in `raiseOrder` — which is exactly the slot
    /// the circle raises last within a pile so its title bar
    /// stays visible. It is last raised on the whole display only
    /// when the count fills the grid evenly (see the test below);
    /// when it does not, the cells raised after it do not touch it.
    ///
    /// Asserted through the shipped `raiseOrder` and `dimension`
    /// rather than a restatement of the partition.
    @Test("The window placed last is raised after its cell-mates")
    func placedLastIsRaisedAfterItsCellMates() throws {
        var state = makeState()
        addWindows(&state, [1, 2, 3, 4, 5])
        let groups = WindowGather.collect(
            state: state,
            primaryHeight: primaryH,
            placingLast: WindowID(2)
        )
        let group = try #require(groups.first)
        let depth = QuitGridLayout.defaultTargetDepth
        let dim = QuitGridLayout.dimension(
            for: group.windows.count,
            targetDepth: depth
        )
        let cells = dim * dim
        // Its cell-mates are the entries sharing its index modulo
        // the cell count — the round-robin `frames` and
        // `raiseOrder` both fill from.
        let mine = group.windows.count - 1
        let mates = group.windows.enumerated()
            .filter { $0.offset % cells == mine % cells }
            .map(\.element)
        #expect(mates.count > 1)
        #expect(mates.last == WindowID(2))
        let circle = QuitGridLayout.raiseOrder(
            for: group.windows,
            targetDepth: depth
        )
        let positions = mates.compactMap(circle.firstIndex(of:))
        #expect(positions.max() == circle.firstIndex(of: WindowID(2)))
    }

    /// And when the count fills the grid evenly it is also the last
    /// window raised on the display, which is the strongest form of
    /// the same property.
    @Test("A full grid raises the placed-last window last of all")
    func placedLastIsRaisedLastWhenTheGridFillsEvenly() throws {
        var state = makeState()
        addWindows(&state, [1, 2, 3, 4])
        let groups = WindowGather.collect(
            state: state,
            primaryHeight: primaryH,
            placingLast: WindowID(2)
        )
        let group = try #require(groups.first)
        let circle = QuitGridLayout.raiseOrder(
            for: group.windows,
            targetDepth: QuitGridLayout.defaultTargetDepth
        )
        #expect(circle.count == 4)
        #expect(circle.last == WindowID(2))
    }
}
