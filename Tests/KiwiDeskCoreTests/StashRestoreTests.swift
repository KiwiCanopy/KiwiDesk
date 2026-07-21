import CoreGraphics
import Testing

@testable import KiwiDeskCore

private func makeWindow(
    _ id: UInt32,
    frame: CGRect = CGRect(
        x: 100,
        y: 100,
        width: 800,
        height: 600
    ),
    floating: Bool = false
) -> ManagedWindow {
    ManagedWindow(
        id: WindowID(id),
        pid: 100,
        appName: "TestApp",
        title: "Doc",
        frame: frame,
        isFloating: floating
    )
}

private let bounds = CGRect(
    x: 0,
    y: 25,
    width: 1920,
    height: 1055
)

/// Floating windows stash with their space (#412): the engine
/// captures a floating window's original frame on first stash
/// and hands it back through the restore pass. These pin the
/// `stashedFrames` bookkeeping; the frame-sets themselves are
/// AX side effects outside the harness.
@Suite("Floating stash capture")
@MainActor
struct StashCaptureTests {
    @Test("First stash captures a floating window's frame")
    func capturesFloatingOnce() {
        let engine = TilingEngine()
        let window = makeWindow(1, floating: true)
        engine.stash(window, in: bounds, force: true)
        #expect(
            engine.stashedFrames[WindowID(1)] == window.frame
        )
    }

    @Test("A forced re-stash keeps the original capture")
    func reStashKeepsOriginal() {
        let engine = TilingEngine()
        let window = makeWindow(1, floating: true)
        engine.stash(window, in: bounds, force: true)
        // The AX echo of the stash updated state: the window
        // now reads at the corner. A later forced retile
        // re-stashes it — the capture must survive.
        var echoed = window
        echoed.frame = TilingEngine.stashFrame(
            window.frame,
            in: bounds
        )
        engine.stash(echoed, in: bounds, force: true)
        #expect(
            engine.stashedFrames[WindowID(1)] == window.frame
        )
    }

    @Test("Tiled windows are stashed without a capture")
    func tiledNotCaptured() {
        let engine = TilingEngine()
        engine.stash(
            makeWindow(1, floating: false),
            in: bounds,
            force: true
        )
        #expect(engine.stashedFrames.isEmpty)
    }
}

@Suite("Floating stash restore")
@MainActor
struct StashRestoreTests {
    /// Two spaces; window 1 on space 1, window 2 on space 2.
    /// Space 1 is active.
    private func makeState() -> StateCoordinator {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.workspaces.ensureSpace(SpaceID(2))
        state.workspaces.activate(SpaceID(2))
        state.apply(.windowCreated(makeWindow(2)))
        state.workspaces.activate(SpaceID(1))
        return state
    }

    @Test("Activating a space consumes its windows' captures")
    func consumesActiveEntries() {
        let engine = TilingEngine()
        let state = makeState()
        let original = CGRect(
            x: 10, y: 20, width: 300, height: 200
        )
        engine.stashedFrames[WindowID(1)] = original
        engine.restoreStashed(state: state, frames: [:])
        #expect(engine.stashedFrames[WindowID(1)] == nil)
    }

    @Test("Inactive spaces keep their windows' captures")
    func keepsInactiveEntries() {
        let engine = TilingEngine()
        let state = makeState()
        let original = CGRect(
            x: 10, y: 20, width: 300, height: 200
        )
        engine.stashedFrames[WindowID(2)] = original
        engine.restoreStashed(state: state, frames: [:])
        #expect(
            engine.stashedFrames[WindowID(2)] == original
        )
    }

    @Test("A layout-owned window drops its stale capture")
    func layoutOwnedDropsEntry() {
        // Unfloated while stashed: the retile's frames now
        // place it; the captured floating frame must not be
        // re-applied over the layout's slot.
        let engine = TilingEngine()
        let state = makeState()
        engine.stashedFrames[WindowID(1)] = .zero
        engine.restoreStashed(
            state: state,
            frames: [
                WindowID(1): CGRect(
                    x: 0, y: 0, width: 500, height: 500
                )
            ]
        )
        #expect(engine.stashedFrames[WindowID(1)] == nil)
    }

    @Test("Captures of departed windows are swept")
    func sweepsDepartedWindows() {
        let engine = TilingEngine()
        let state = makeState()
        engine.stashedFrames[WindowID(99)] = .zero
        engine.restoreStashed(state: state, frames: [:])
        #expect(engine.stashedFrames[WindowID(99)] == nil)
    }
}
