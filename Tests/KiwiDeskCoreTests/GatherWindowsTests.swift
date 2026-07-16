import CoreGraphics
import Testing

@testable import KiwiDeskCore

// MARK: - Shared fixtures

// Single 1920×1080 display, Cocoa coordinates.
private let displayFrame = CGRect(
    x: 0,
    y: 0,
    width: 1920,
    height: 1080
)
// visibleFrame excludes the 25-pt menu bar strip (Cocoa).
private let cocoaVisible = CGRect(
    x: 0,
    y: 0,
    width: 1920,
    height: 1055
)
// AX visible: flip(cocoaVisible, pH: 1080)
//   y = 1080 − (0 + 1055) = 25, height = 1055
private let axVisible = CGRect(
    x: 0,
    y: 25,
    width: 1920,
    height: 1055
)
private let primaryH: CGFloat = 1080
private let minSize: CGFloat = 300

// MARK: - Helpers

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

private func addWindow(
    _ state: inout StateCoordinator,
    id: UInt32,
    size: CGSize = CGSize(width: 800, height: 600),
    isFloating: Bool = false
) {
    let w = ManagedWindow(
        id: WindowID(id),
        pid: 99,
        appName: "TestApp",
        title: "",
        frame: CGRect(
            x: 0,
            y: 0,
            width: size.width,
            height: size.height
        ),
        isFloating: isFloating
    )
    state.apply(.windowCreated(w))
}

private func targets(
    _ state: StateCoordinator
) -> [WindowID: CGRect] {
    WindowGather.targets(
        state: state,
        primaryHeight: primaryH,
        style: .grid,
        minSize: minSize,
        targetDepth: QuitGridLayout.defaultTargetDepth
    )
}

// MARK: - Target resolution

@Suite("WindowGather — targets")
struct GatherTargetsTests {
    @Test("a lone tiled window fills the top-left grid cell")
    func tiledWindowInFirstCell() throws {
        var state = makeState()
        addWindow(&state, id: 42)
        let frames = targets(state)
        let frame = try #require(frames[WindowID(42)])
        // 2×2 grid over axVisible → 960 × 527.5 cells.
        #expect(
            frame
                == CGRect(
                    x: 0,
                    y: 25,
                    width: 960,
                    height: 527.5
                )
        )
    }

    @Test("windows are resized to the cell, not kept")
    func resizesToCell() throws {
        var state = makeState()
        addWindow(
            &state,
            id: 1,
            size: CGSize(width: 320, height: 240)
        )
        let frames = targets(state)
        let frame = try #require(frames[WindowID(1)])
        #expect(frame.width == 960)
        #expect(frame.height == 527.5)
    }

    @Test("floating windows are excluded")
    func skipsFloating() {
        var state = makeState()
        addWindow(&state, id: 99, isFloating: true)
        let frames = targets(state)
        #expect(frames[WindowID(99)] == nil)
    }

    @Test("windows with zero-size frame are excluded")
    func skipsZeroFrame() {
        var state = makeState()
        // Default frame is .zero → should be excluded.
        let w = ManagedWindow(
            id: WindowID(7),
            pid: 99,
            appName: "App"
        )
        state.apply(.windowCreated(w))
        let frames = targets(state)
        #expect(frames[WindowID(7)] == nil)
    }

    @Test("empty display list returns no targets")
    func emptyDisplays() {
        // No displays registered — targets must be empty.
        var s = StateCoordinator(defaultSpace: SpaceID(1))
        addWindow(&s, id: 5)
        let frames = targets(s)
        #expect(frames.isEmpty)
    }

    @Test("window in unassigned space falls back to first display")
    func fallsBackToFirstDisplay() throws {
        var state = makeState()
        // Add a second space with no display assignment,
        // then move a window there.
        state.workspaces.ensureSpace(SpaceID(99))
        let w = ManagedWindow(
            id: WindowID(55),
            pid: 99,
            appName: "App",
            title: "",
            frame: CGRect(
                x: 0,
                y: 0,
                width: 800,
                height: 600
            )
        )
        state.apply(.windowCreated(w))
        // Relocate to the display-less space.
        state.workspaces.add(WindowID(55), to: SpaceID(99))
        let frames = targets(state)
        // Falls back to the first (and only) display.
        let frame = try #require(frames[WindowID(55)])
        #expect(frame.minX >= axVisible.minX)
        #expect(frame.maxX <= axVisible.maxX)
    }

    @Test("collect merges all of a display's spaces: 6+2 = one 8")
    func collectMergesSpacesPerDisplay() throws {
        // The 3-3-1-1 regression shape: 6 windows on one
        // virtual space and 2 on another, same display, must
        // form ONE group of 8 (→ 2-2-2-2 round-robin), never
        // two separately-gridded batches.
        var state = makeState()
        state.workspaces.assign(SpaceID(2), to: DisplayID(1))
        for id in UInt32(1)...6 {
            addWindow(&state, id: id)
        }
        for id in UInt32(7)...8 {
            let w = ManagedWindow(
                id: WindowID(id),
                pid: 99,
                appName: "App",
                title: "",
                frame: CGRect(
                    x: 0,
                    y: 0,
                    width: 800,
                    height: 600
                )
            )
            state.apply(.windowCreated(w))
            state.workspaces.add(WindowID(id), to: SpaceID(2))
        }
        let groups = WindowGather.collect(
            state: state,
            primaryHeight: primaryH
        )
        #expect(groups.count == 1)
        let group = try #require(groups.first)
        #expect(group.windows.count == 8)
        // And the grid over it fills every cell twice.
        let frames = targets(state)
        var counts: [String: Int] = [:]
        for frame in frames.values {
            // Bucket by cell column/row, ignoring cascade
            // offsets within the cell.
            let col = Int(frame.minX / 960)
            let row = Int((frame.minY - 25) / 527.5)
            counts["\(col),\(row)", default: 0] += 1
        }
        #expect(counts.values.allSatisfy { $0 == 2 })
        #expect(counts.count == 4)
    }

    @Test("windows across spaces share one display-wide grid")
    func spacesShareTheDisplayGrid() throws {
        var state = makeState()
        // Second space on the same display: its window must
        // round-robin into the same grid, not restart it.
        state.workspaces.assign(SpaceID(2), to: DisplayID(1))
        addWindow(&state, id: 1)
        let w = ManagedWindow(
            id: WindowID(2),
            pid: 99,
            appName: "App",
            title: "",
            frame: CGRect(
                x: 0,
                y: 0,
                width: 800,
                height: 600
            )
        )
        state.apply(.windowCreated(w))
        state.workspaces.add(WindowID(2), to: SpaceID(2))
        let frames = targets(state)
        let f1 = try #require(frames[WindowID(1)])
        let f2 = try #require(frames[WindowID(2)])
        // Cell 0 and cell 1 — no overlap, same row.
        #expect(f1.origin == CGPoint(x: 0, y: 25))
        #expect(f2.origin == CGPoint(x: 960, y: 25))
    }
}
