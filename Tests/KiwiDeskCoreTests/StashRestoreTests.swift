import CoreGraphics
import Foundation
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
        engine.stash(window, in: bounds, corner: .bottomRight, force: true)
        #expect(
            engine.stashedFrames[WindowID(1)] == window.frame
        )
    }

    @Test("A forced re-stash keeps the original capture")
    func reStashKeepsOriginal() {
        let engine = TilingEngine()
        let window = makeWindow(1, floating: true)
        engine.stash(window, in: bounds, corner: .bottomRight, force: true)
        // The AX echo of the stash updated state: the window
        // now reads at the corner. A later forced retile
        // re-stashes it — the capture must survive.
        var echoed = window
        echoed.frame = TilingEngine.stashFrame(
            window.frame,
            in: bounds,
            corner: .bottomRight
        )
        engine.stash(
            echoed,
            in: bounds,
            corner: .bottomRight,
            force: true
        )
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
            corner: .bottomRight,
            force: true
        )
        #expect(engine.stashedFrames.isEmpty)
    }

    /// #500: `stashInactive` passes the EFFECTIVE-float verdict
    /// — a floating-MODE space's member captures whatever its
    /// own flag, since no layout will place it on return.
    @Test("The effective-float override captures a tiled window")
    func effectiveFloatOverrideCaptures() {
        let engine = TilingEngine()
        let window = makeWindow(1, floating: false)
        engine.stash(
            window,
            in: bounds,
            corner: .bottomRight,
            force: true,
            capturesOriginal: true
        )
        #expect(
            engine.stashedFrames[WindowID(1)] == window.frame
        )
    }

    /// The sticky exemption moved out of `stash` into the
    /// `stickyExemptFromStash` predicate applied by `stashInactive`
    /// (#445), so `stash` itself now parks whatever it is handed —
    /// the exemption is proven at the predicate below.
    @Test("A global sticky window is exempt from the stash (#414)")
    func stickyExempt() {
        let state = StateCoordinator()
        let window = ManagedWindow(
            id: WindowID(1),
            pid: 100,
            appName: "TestApp",
            stickyScope: .global
        )
        // Global is exempt on any space, no membership needed.
        #expect(
            state.stickyExemptFromStash(window, onSpace: SpaceID(9))
        )
        let plain = makeWindow(2)
        #expect(
            !state.stickyExemptFromStash(plain, onSpace: SpaceID(9))
        )
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

    @Test("A capture survives until the restore echo lands")
    func consumesOnlyOnEcho() {
        let engine = TilingEngine()
        var state = makeState()
        let original = CGRect(
            x: 10,
            y: 20,
            width: 300,
            height: 200
        )
        engine.stashedFrames[WindowID(1)] = original
        // The state frame still reads elsewhere (the corner /
        // the stale echo): the restore is issued but the entry
        // must survive — consuming eagerly is the rapid-bounce
        // hole that re-captured the corner as "original".
        engine.restoreStashed(state: state, frames: [:])
        #expect(
            engine.stashedFrames[WindowID(1)] == original
        )
        // A re-stash while the entry lives cannot re-capture
        // (nil guard) — see `reStashKeepsOriginal`.
        // The echo lands: the state frame reads the original,
        // and the next retile consumes the capture.
        state.apply(.windowMoved(WindowID(1), original))
        engine.restoreStashed(state: state, frames: [:])
        #expect(engine.stashedFrames[WindowID(1)] == nil)
    }

    @Test("A user move consumes the capture (forgetStash)")
    func userMoveForgets() {
        let engine = TilingEngine()
        engine.stashedFrames[WindowID(1)] = .zero
        engine.forgetStash(WindowID(1))
        #expect(engine.stashedFrames.isEmpty)
    }

    @Test("A drag-exempt window keeps its capture untouched")
    func dragExemptKeepsEntry() {
        let engine = TilingEngine()
        let state = makeState()
        engine.dragExemptWindow = WindowID(1)
        engine.stashedFrames[WindowID(1)] = .zero
        engine.restoreStashed(state: state, frames: [:])
        #expect(
            engine.stashedFrames[WindowID(1)] == .zero
        )
    }

    @Test("Inactive spaces keep their windows' captures")
    func keepsInactiveEntries() {
        let engine = TilingEngine()
        let state = makeState()
        let original = CGRect(
            x: 10,
            y: 20,
            width: 300,
            height: 200
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
                    x: 0,
                    y: 0,
                    width: 500,
                    height: 500
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

    /// A native-tab re-key (#308) while a floating window is
    /// stashed must carry the capture to the new id — or the
    /// sweep drops it and the window stays parked at the
    /// corner forever (#412's failure mode, on this one path).
    @Test("A rekey carries the stash capture to the new id")
    @MainActor
    func rekeyCarriesCapture() {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-stash-rekey-\(UUID().uuidString)"
                )
        )
        core.state.apply(
            .windowCreated(makeWindow(1, floating: true))
        )
        // Stashed = the window's home space is inactive; on
        // the active space the restore pass would (rightly)
        // consume the capture during the rekey's retile.
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.state.workspaces.activate(SpaceID(2))
        let original = CGRect(
            x: 10,
            y: 20,
            width: 300,
            height: 200
        )
        core.tiler.stashedFrames[WindowID(1)] = original
        core.handle(.windowRekeyed(WindowID(1), WindowID(2)))
        #expect(
            core.tiler.stashedFrames[WindowID(2)] == original
        )
        #expect(core.tiler.stashedFrames[WindowID(1)] == nil)
    }
}
