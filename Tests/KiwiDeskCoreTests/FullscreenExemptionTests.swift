import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

// #670: on a native-fullscreen space KiwiDesk stands down — no
// bars, no settle retile, no focus raise — and a fullscreen
// window is exempt from layout passes while it is away on its
// own macOS Space. It stays a member of its home virtual space
// (fullscreen is not a destroy — `FullscreenStateTests` pins the
// flag itself); these suites pin what the flag now *does*.

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

private func makeWindow(_ id: WindowID) -> ManagedWindow {
    ManagedWindow(
        id: id,
        pid: pid_t(id.raw),
        appName: "App\(id.raw)"
    )
}

/// The membership half: a fullscreen window leaves the tiled
/// working set (layout, navigation, z-order all read these two
/// derivations) but keeps its bar glyph and its slot in
/// `space.windows`.
@Suite("Fullscreen layout exemption (#670)")
struct FullscreenLayoutExemptionTests {
    private func makeState() -> StateCoordinator {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(w1)))
        state.apply(.windowCreated(makeWindow(w2)))
        state.apply(.windowCreated(makeWindow(w3)))
        return state
    }

    @Test("A fullscreen window leaves the tiled member lists")
    func tiledMembershipExemption() {
        var state = makeState()
        state.apply(
            .windowFullscreenChanged(w2, isFullscreen: true)
        )
        let space = state.workspaces[
            state.workspaces.activeSpace!
        ]!
        #expect(state.localTiledMembers(of: space) == [w1, w3])
        #expect(
            state.effectiveTiledMembers(of: space) == [w1, w3]
        )
        // The slot itself survives — fullscreen is not a
        // destroy, and the exit retile re-places from it.
        #expect(space.windows == [w1, w2, w3])
    }

    @Test("Leaving fullscreen re-enters the tiled member lists")
    func exitRestoresMembership() {
        var state = makeState()
        state.apply(
            .windowFullscreenChanged(w2, isFullscreen: true)
        )
        state.apply(
            .windowFullscreenChanged(w2, isFullscreen: false)
        )
        let space = state.workspaces[
            state.workspaces.activeSpace!
        ]!
        #expect(
            state.localTiledMembers(of: space) == [w1, w2, w3]
        )
    }

    @Test("The bar glyph stays, in place, with no duplicates")
    func presentationMembershipKept() {
        var state = makeState()
        state.apply(
            .windowFullscreenChanged(w2, isFullscreen: true)
        )
        let space = state.workspaces[
            state.workspaces.activeSpace!
        ]!
        // `effectiveMembers` drives the Space Bar: the window
        // is still a member of this space, so its glyph stays —
        // and the tiled-cursor merge must not drain past the
        // exempt id (which would duplicate every later member).
        #expect(state.effectiveMembers(of: space) == [w1, w2, w3])
    }
}

/// The stand-down half: the user-space verdict and the surfaces
/// it gates (both bars, the 600 ms native-switch settle).
/// Serialized: the DEBUG overrides are process-global.
@Suite(
    "Fullscreen space stand-down (#670)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct FullscreenStandDownTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-fullscreen-\(UUID().uuidString)"
                )
        )
    }

    private func space(
        _ id: UInt64,
        isUser: Bool
    ) -> NativeSpace {
        NativeSpace(
            id: id,
            displayUUID: "D",
            isCurrent: false,
            isUser: isUser
        )
    }

    @Test("The verdict reads isUser; a lookup miss counts user")
    func isUserSpaceVerdict() {
        let spaces = [
            space(1, isUser: true),
            space(9, isUser: false),
        ]
        #expect(NativeSpaces.isUserSpace(1, in: spaces))
        #expect(!NativeSpaces.isUserSpace(9, in: spaces))
        // Standing down needs positive evidence of a
        // fullscreen/system space — never a miss (an unknown id
        // must not hide the bars or kill the settle).
        #expect(NativeSpaces.isUserSpace(42, in: spaces))
    }

    @Test("The native-switch settle stands down on a fullscreen space")
    func settleStandsDown() {
        let core = makeCore()
        core.state.apply(.windowCreated(makeWindow(w1)))
        core.state.apply(.windowCreated(makeWindow(w2)))
        let spaceID = core.state.workspaces.space(of: w1)!
        core.state.workspaces.focus(w2, in: spaceID)
        // Destroying the focused window hands `focused` to the
        // fallback but clears the global `lastFocused` — the
        // settle's refocus is then the only thing that can set
        // it, which makes it the probe.
        core.state.apply(
            .windowDestroyed(w2, wasMinimized: false)
        )
        #expect(
            core.state.workspaces[spaceID]?.focused == w1
        )
        #expect(core.state.workspaces.lastFocused == nil)

        NativeSpaces.activeSpaceIsUserOverride = false
        defer { NativeSpaces.activeSpaceIsUserOverride = nil }
        core.nativeSpaceSettle(ifStill: core.lastNativeSpace)
        // Stood down: no retile, no refocus behind the
        // fullscreen app.
        #expect(core.state.workspaces.lastFocused == nil)

        // Back on a user desktop the same settle refocuses —
        // proving the gate, not a broken settle body.
        NativeSpaces.activeSpaceIsUserOverride = true
        core.nativeSpaceSettle(ifStill: core.lastNativeSpace)
        #expect(core.state.workspaces.lastFocused == w1)
    }

    @Test("The inactive-space stash skips a fullscreen window")
    func stashSkipsFullscreen() {
        guard let screen = NSScreen.main else { return }
        // A floating member of an inactive space is captured on
        // its first stash — the probe: a fullscreen one must be
        // skipped before that capture (it lives on its own
        // macOS Space; there is nothing here to park).
        func makeState(fullscreen: Bool) -> StateCoordinator {
            var state = StateCoordinator()
            state.apply(.windowCreated(makeWindow(w1)))
            state.workspaces.ensureSpace(SpaceID(2))
            state.workspaces.activate(SpaceID(2))
            state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: w2,
                        pid: 2,
                        appName: "App2",
                        frame: CGRect(
                            x: 100,
                            y: 100,
                            width: 800,
                            height: 600
                        ),
                        isFloating: true,
                        isFullscreen: fullscreen
                    )
                )
            )
            state.workspaces.activate(SpaceID(1))
            return state
        }
        // Control arm first: the same fixture without the flag
        // captures, so the skip below is the guard passing —
        // not a fixture that never reached the stash.
        let engine = TilingEngine()
        engine.stashInactive(
            state: makeState(fullscreen: false),
            fallback: screen,
            force: true
        )
        #expect(engine.stashedFrames[w2] != nil)

        let exempt = TilingEngine()
        exempt.stashInactive(
            state: makeState(fullscreen: true),
            fallback: screen,
            force: true
        )
        #expect(exempt.stashedFrames[w2] == nil)
    }

    @Test("The App Bar's cold-start fallback hides on a fullscreen space")
    func appBarFallbackHides() {
        let core = makeCore()
        core.state.apply(.windowCreated(makeWindow(w1)))
        core.state.apply(.windowCreated(makeWindow(w2)))
        let spaceID = core.state.workspaces.space(of: w1)!
        _ = core.execute(
            "set_mode",
            args: [.string(spaceID.raw), .string("monocle")]
        )
        defer { NativeSpaces.activeSpaceIsUserOverride = nil }

        // On a user desktop the fixture paints a bar — the
        // stand-down below must be the gate, not a bar that
        // never rendered.
        NativeSpaces.activeSpaceIsUserOverride = true
        core.updateAppBar()
        #expect(!core.appBars.shownStrips.isEmpty)

        NativeSpaces.activeSpaceIsUserOverride = false
        core.updateAppBar()
        #expect(core.appBars.shownStrips.isEmpty)
    }

    @Test("Both per-display bars hide on a fullscreen space")
    func perDisplayBarsHide() {
        let core = makeCore()
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay
        else { return }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(.windowCreated(makeWindow(w1)))
        core.state.apply(.windowCreated(makeWindow(w2)))
        // The event pump normally follows a display change with
        // this; applying the raw state event skips KiwiCore.
        core.resolveSpaceDisplays(mainID: display.id)
        let spaceID = core.state.workspaces.space(of: w1)!
        _ = core.execute(
            "set_mode",
            args: [.string(spaceID.raw), .string("monocle")]
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }

        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateAppBar()
        core.updateSpaceBar()
        #expect(!core.appBars.shownStrips.isEmpty)
        #expect(!core.spaceBars.shownDisplays.isEmpty)

        NativeSpaces.currentSpaceIsUserOverride = { _ in false }
        core.updateAppBar()
        core.updateSpaceBar()
        #expect(core.appBars.shownStrips.isEmpty)
        #expect(core.spaceBars.shownDisplays.isEmpty)
    }
}
