import CoreGraphics
import Testing

@testable import KiwiDeskCore

// MARK: - Fixtures

// Two side-by-side 1920×1080 displays in Cocoa coordinates.
// Display 1: x=[0, 1920), primaryH = 1080
// Display 2: x=[1920, 3840), same height
private let pH: CGFloat = 1080
private let minSize: CGFloat = 300

private let display1 = Display(
    id: DisplayID(1),
    name: "Main",
    frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(
        x: 0,
        y: 0,
        width: 1920,
        height: 1055
    )
)

// AX coordinates: y = 1080 − (0 + 1055) = 25
private let axVisible1 = CGRect(
    x: 0,
    y: 25,
    width: 1920,
    height: 1055
)

private let display2 = Display(
    id: DisplayID(2),
    name: "External",
    frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(
        x: 1920,
        y: 0,
        width: 1920,
        height: 1055
    )
)

// AX coordinates: y = 25, x offset = 1920
private let axVisible2 = CGRect(
    x: 1920,
    y: 25,
    width: 1920,
    height: 1055
)

private func makeState() -> StateCoordinator {
    var s = StateCoordinator(defaultSpace: SpaceID(1))
    s.workspaces.upsertDisplay(display1)
    s.workspaces.upsertDisplay(display2)
    s.workspaces.assign(SpaceID(1), to: DisplayID(1))
    s.workspaces.assign(SpaceID(2), to: DisplayID(2))
    return s
}

private func addWindow(
    _ state: inout StateCoordinator,
    id: UInt32,
    space: SpaceID,
    size: CGSize = CGSize(width: 400, height: 300)
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
        )
    )
    state.apply(.windowCreated(w))
    state.workspaces.add(WindowID(id), to: space)
}

private func targets(
    _ state: StateCoordinator
) -> [WindowID: CGRect] {
    WindowGather.targets(
        state: state,
        primaryHeight: pH,
        style: .grid,
        minSize: minSize
    )
}

// MARK: - Multi-display targets

@Suite("WindowGather — multi-display grid")
struct GatherMultiDisplayTests {
    @Test("each window grids within its own display")
    func eachWindowOnOwnDisplay() throws {
        var state = makeState()
        addWindow(&state, id: 1, space: SpaceID(1))
        addWindow(&state, id: 2, space: SpaceID(2))
        let frames = targets(state)
        let f1 = try #require(frames[WindowID(1)])
        let f2 = try #require(frames[WindowID(2)])
        // Both are lone → top-left 2×2 cell of their display.
        // No cross-monitor pull.
        #expect(f1.origin == axVisible1.origin)
        #expect(f2.origin == axVisible2.origin)
        #expect(f1.width == 960)
        #expect(f2.width == 960)
    }

    @Test("displays size their grids independently")
    func independentGridSizing() throws {
        var state = makeState()
        // 41 windows on display 1 → 3×3; one on display 2
        // stays 2×2.
        for id in UInt32(1)...41 {
            addWindow(&state, id: id, space: SpaceID(1))
        }
        addWindow(&state, id: 100, space: SpaceID(2))
        let frames = targets(state)
        // Display 1's second window sits at a third of its
        // width; display 2's lone window fills a half-width
        // cell.
        let f2 = try #require(frames[WindowID(2)])
        #expect(f2.minX == 640)
        let f100 = try #require(frames[WindowID(100)])
        #expect(f100.width == 960)
        #expect(f100.minX == 1920)
    }

    @Test("round-robin wraps into a cascade per display")
    func roundRobinCascades() throws {
        var state = makeState()
        for id in UInt32(1)...5 {
            addWindow(&state, id: id, space: SpaceID(1))
        }
        let frames = targets(state)
        let f1 = try #require(frames[WindowID(1)])
        let f5 = try #require(frames[WindowID(5)])
        // Window 5 wraps back onto window 1's cell, offset
        // down by the cascade step.
        #expect(f5.minX == f1.minX)
        #expect(f5.minY == f1.minY + OverlapStack.offset)
    }

    @Test("unassigned space falls back to lowest-ID display")
    func deterministicFallback() throws {
        // Three displays: IDs 5, 2, 1 — inserted in that
        // order to exercise the unordered-dict issue.
        var s = StateCoordinator(defaultSpace: SpaceID(1))
        let d5 = Display(
            id: DisplayID(5),
            name: "D5",
            frame: CGRect(
                x: 3840,
                y: 0,
                width: 1920,
                height: 1080
            ),
            visibleFrame: CGRect(
                x: 3840,
                y: 0,
                width: 1920,
                height: 1055
            )
        )
        let d2 = Display(
            id: DisplayID(2),
            name: "D2",
            frame: CGRect(
                x: 1920,
                y: 0,
                width: 1920,
                height: 1080
            ),
            visibleFrame: CGRect(
                x: 1920,
                y: 0,
                width: 1920,
                height: 1055
            )
        )
        let d1 = Display(
            id: DisplayID(1),
            name: "D1",
            frame: CGRect(
                x: 0,
                y: 0,
                width: 1920,
                height: 1080
            ),
            visibleFrame: CGRect(
                x: 0,
                y: 0,
                width: 1920,
                height: 1055
            )
        )
        s.workspaces.upsertDisplay(d5)
        s.workspaces.upsertDisplay(d2)
        s.workspaces.upsertDisplay(d1)
        // Space 99 has no display assignment → fallback.
        s.workspaces.ensureSpace(SpaceID(99))
        let w = ManagedWindow(
            id: WindowID(77),
            pid: 99,
            appName: "App",
            title: "",
            frame: CGRect(
                x: 0,
                y: 0,
                width: 400,
                height: 300
            )
        )
        s.apply(.windowCreated(w))
        s.workspaces.add(WindowID(77), to: SpaceID(99))
        let frames = targets(s)
        let f = try #require(frames[WindowID(77)])
        // Lowest raw ID is 1 → display d1, x=[0, 1920).
        #expect(f.minX >= 0)
        #expect(f.maxX <= 1920)
    }
}
