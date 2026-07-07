import CoreGraphics
import Testing

@testable import KiwiDeskCore

// MARK: - Fixtures

// Two side-by-side 1920×1080 displays in Cocoa coordinates.
// Display 1: x=[0, 1920), primaryH = 1080
// Display 2: x=[1920, 3840), same height
private let pH: CGFloat = 1080

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

// MARK: - staggeredFrame math

@Suite("WindowGather — staggeredFrame")
struct GatherStaggerFrameTests {
    private let frame = CGRect(
        x: 0,
        y: 25,
        width: 1920,
        height: 1055
    )
    private let size = CGSize(width: 400, height: 300)

    @Test("index 0 is centered — same as centeredFrame")
    func index0MatchesCenteredFrame() {
        let stag = WindowGather.staggeredFrame(
            size: size,
            in: frame,
            index: 0
        )
        let cent = WindowGather.centeredFrame(
            size: size,
            in: frame
        )
        #expect(stag == cent)
        #expect(abs(stag.midX - frame.midX) < 1)
        #expect(abs(stag.midY - frame.midY) < 1)
    }

    @Test("index 1 offsets diagonally by staggerStep")
    func index1IsOffset() {
        let step = WindowGather.staggerStep
        let s0 = WindowGather.staggeredFrame(
            size: size,
            in: frame,
            index: 0
        )
        let s1 = WindowGather.staggeredFrame(
            size: size,
            in: frame,
            index: 1
        )
        #expect(abs(s1.minX - (s0.minX + step)) < 1)
        #expect(abs(s1.minY - (s0.minY + step)) < 1)
    }

    @Test("large index clamps within axFrame")
    func largeIndexClamps() {
        let result = WindowGather.staggeredFrame(
            size: size,
            in: frame,
            index: 10_000
        )
        #expect(result.minX >= frame.minX)
        #expect(result.minY >= frame.minY)
        #expect(result.maxX <= frame.maxX)
        #expect(result.maxY <= frame.maxY)
    }

    @Test("staggered frames remain inside axFrame for many windows")
    func manyWindowsAllInsideBounds() {
        for idx in 0..<50 {
            let r = WindowGather.staggeredFrame(
                size: size,
                in: frame,
                index: idx
            )
            #expect(r.minX >= frame.minX)
            #expect(r.minY >= frame.minY)
            #expect(r.maxX <= frame.maxX)
            #expect(r.maxY <= frame.maxY)
        }
    }
}

// MARK: - Multi-display targets

@Suite("WindowGather — multi-display targets")
struct GatherMultiDisplayTests {
    @Test("each window lands within its own display's axVisible")
    func eachWindowOnOwnDisplay() {
        var state = makeState()
        addWindow(&state, id: 1, space: SpaceID(1))
        addWindow(&state, id: 2, space: SpaceID(2))
        let frames = WindowGather.targets(
            state: state,
            primaryHeight: pH
        )
        guard let f1 = frames[WindowID(1)] else {
            Issue.record("no frame for window 1")
            return
        }
        guard let f2 = frames[WindowID(2)] else {
            Issue.record("no frame for window 2")
            return
        }
        // Window 1 must be inside display1's axVisible frame.
        #expect(f1.minX >= axVisible1.minX)
        #expect(f1.maxX <= axVisible1.maxX)
        #expect(f1.minY >= axVisible1.minY)
        #expect(f1.maxY <= axVisible1.maxY)
        // Window 2 must be inside display2's axVisible frame.
        #expect(f2.minX >= axVisible2.minX)
        #expect(f2.maxX <= axVisible2.maxX)
        #expect(f2.minY >= axVisible2.minY)
        #expect(f2.maxY <= axVisible2.maxY)
    }

    @Test("first window per display is at display center")
    func firstWindowPerDisplayIsAtCenter() {
        var state = makeState()
        addWindow(&state, id: 1, space: SpaceID(1))
        addWindow(&state, id: 2, space: SpaceID(2))
        let frames = WindowGather.targets(
            state: state,
            primaryHeight: pH
        )
        guard let f1 = frames[WindowID(1)] else {
            Issue.record("no frame for window 1")
            return
        }
        guard let f2 = frames[WindowID(2)] else {
            Issue.record("no frame for window 2")
            return
        }
        #expect(abs(f1.midX - axVisible1.midX) < 1)
        #expect(abs(f1.midY - axVisible1.midY) < 1)
        #expect(abs(f2.midX - axVisible2.midX) < 1)
        #expect(abs(f2.midY - axVisible2.midY) < 1)
    }

    @Test("two windows on same display are staggered apart")
    func twoWindowsSameDisplayAreStaggered() {
        var state = makeState()
        addWindow(&state, id: 10, space: SpaceID(1))
        addWindow(&state, id: 11, space: SpaceID(1))
        let frames = WindowGather.targets(
            state: state,
            primaryHeight: pH
        )
        guard let f10 = frames[WindowID(10)],
            let f11 = frames[WindowID(11)]
        else {
            Issue.record("missing frame(s)")
            return
        }
        // They must not be at the exact same position.
        #expect(f10.origin != f11.origin)
        // The step should be the configured constant.
        let step = WindowGather.staggerStep
        #expect(
            abs(abs(f11.minX - f10.minX) - step) < 1
                || f11.minX == axVisible1.minX
                || f11.maxX == axVisible1.maxX
        )
    }

    @Test("unassigned space falls back to lowest-ID display")
    func deterministicFallback() {
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
        let frames = WindowGather.targets(
            state: s,
            primaryHeight: 1080
        )
        guard let f = frames[WindowID(77)] else {
            Issue.record("no frame for window 77")
            return
        }
        // Lowest raw ID is 1 → display d1, x=[0, 1920).
        let axD1 = CGRect(
            x: 0,
            y: 25,
            width: 1920,
            height: 1055
        )
        #expect(f.minX >= axD1.minX)
        #expect(f.maxX <= axD1.maxX)
        #expect(f.minY >= axD1.minY)
        #expect(f.maxY <= axD1.maxY)
    }
}
