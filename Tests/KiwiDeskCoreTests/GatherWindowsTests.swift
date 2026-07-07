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

// MARK: - Centered-frame math

@Suite("WindowGather — centeredFrame")
struct GatherCenteredFrameTests {
    @Test("window is centered in the display")
    func centersWindow() {
        let size = CGSize(width: 800, height: 600)
        let result = WindowGather.centeredFrame(
            size: size,
            in: axVisible
        )
        #expect(abs(result.midX - axVisible.midX) < 1)
        #expect(abs(result.midY - axVisible.midY) < 1)
        #expect(result.width == 800)
        #expect(result.height == 600)
    }

    @Test("window wider than display clamps to left edge")
    func clampsTooWide() {
        let size = CGSize(width: 2000, height: 600)
        let result = WindowGather.centeredFrame(
            size: size,
            in: axVisible
        )
        #expect(result.minX == axVisible.minX)
    }

    @Test("window taller than display clamps to top edge")
    func clampsTooTall() {
        let size = CGSize(width: 800, height: 2000)
        let result = WindowGather.centeredFrame(
            size: size,
            in: axVisible
        )
        #expect(result.minY == axVisible.minY)
    }

    @Test("result frame sits entirely within axFrame")
    func staysInsideBounds() {
        let size = CGSize(width: 400, height: 300)
        let result = WindowGather.centeredFrame(
            size: size,
            in: axVisible
        )
        #expect(result.minX >= axVisible.minX)
        #expect(result.minY >= axVisible.minY)
        #expect(result.maxX <= axVisible.maxX)
        #expect(result.maxY <= axVisible.maxY)
    }
}

// MARK: - Target resolution

@Suite("WindowGather — targets")
struct GatherTargetsTests {
    @Test("tiled window gets a centered frame on its display")
    func tiledWindowCentered() {
        var state = makeState()
        addWindow(&state, id: 42)
        let frames = WindowGather.targets(
            state: state,
            primaryHeight: primaryH
        )
        guard let frame = frames[WindowID(42)] else {
            Issue.record("no frame resolved for window 42")
            return
        }
        #expect(abs(frame.midX - axVisible.midX) < 1)
        #expect(abs(frame.midY - axVisible.midY) < 1)
        #expect(frame.width == 800)
        #expect(frame.height == 600)
    }

    @Test("floating windows are excluded")
    func skipsFloating() {
        var state = makeState()
        addWindow(&state, id: 99, isFloating: true)
        let frames = WindowGather.targets(
            state: state,
            primaryHeight: primaryH
        )
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
        let frames = WindowGather.targets(
            state: state,
            primaryHeight: primaryH
        )
        #expect(frames[WindowID(7)] == nil)
    }

    @Test("empty display list returns no targets")
    func emptyDisplays() {
        // No displays registered — targets must be empty.
        var s = StateCoordinator(defaultSpace: SpaceID(1))
        addWindow(&s, id: 5)
        let frames = WindowGather.targets(
            state: s,
            primaryHeight: primaryH
        )
        #expect(frames.isEmpty)
    }

    @Test("window in unassigned space falls back to first display")
    func fallsBackToFirstDisplay() {
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
        let frames = WindowGather.targets(
            state: state,
            primaryHeight: primaryH
        )
        // Falls back to the first (and only) display.
        guard let frame = frames[WindowID(55)] else {
            Issue.record("no frame for window 55")
            return
        }
        #expect(abs(frame.midX - axVisible.midX) < 1)
        #expect(abs(frame.midY - axVisible.midY) < 1)
    }
}
