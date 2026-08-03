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

    @Test("A fullscreen sticky keeps its one glyph at home")
    func fullscreenStickyGlyphStaysHome() {
        var state = makeState()
        state.workspaces.ensureSpace(SpaceID(2))
        state.setSticky(w2, .global)
        state.apply(
            .windowFullscreenChanged(w2, isFullscreen: true)
        )
        // Focus lives on space 2: a non-fullscreen global
        // sticky would render (and list) there. Fullscreen
        // excludes it from both traveler injections, so
        // without the home-space keep it would vanish from
        // every bar at once.
        state.workspaces.activate(SpaceID(2))
        let home = state.workspaces[SpaceID(1)]!
        let away = state.workspaces[SpaceID(2)]!
        #expect(
            state.effectiveMembers(
                of: home,
                activeSpace: SpaceID(2)
            ).contains(w2)
        )
        #expect(
            !state.effectiveMembers(
                of: away,
                activeSpace: SpaceID(2)
            ).contains(w2)
        )
    }
}

/// The close fallback: `Space.remove` hands `focused` to the
/// slot neighbor, which can be a fullscreen member — the close
/// handler's raise would then switch the user to its Space, so
/// the fold re-picks (#670 review).
@Suite("Fullscreen close-fallback re-pick (#670)")
struct FullscreenCloseFallbackTests {
    @Test("A close never hands focus to a fullscreen neighbor")
    func closeRePicksPastFullscreen() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(w1)))
        state.apply(.windowCreated(makeWindow(w2)))
        state.apply(.windowCreated(makeWindow(w3)))
        let space = state.workspaces.activeSpace!
        state.workspaces.focus(w1, in: space)
        state.apply(
            .windowFullscreenChanged(w2, isFullscreen: true)
        )
        state.apply(.windowDestroyed(w1, wasMinimized: false))
        // The slot neighbor is w2 (fullscreen) — the fold must
        // step past it to the first surfaceable member.
        #expect(state.workspaces[space]?.focused == w3)
    }

    @Test("The plain slot-neighbor fallback is untouched")
    func plainNeighborFallbackKept() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(w1)))
        state.apply(.windowCreated(makeWindow(w2)))
        let space = state.workspaces.activeSpace!
        state.workspaces.focus(w1, in: space)
        state.apply(.windowDestroyed(w1, wasMinimized: false))
        #expect(state.workspaces[space]?.focused == w2)
    }
}

/// The quit grid gathers every tracked tiled window — except a
/// fullscreen one, which lives on its own macOS Space where the
/// grid can neither reach nor place it, and no post-quit restore
/// heals the poke (#670 review).
@Suite("Fullscreen quit-grid exemption (#670)")
struct FullscreenQuitGridTests {
    @Test("The gather skips a fullscreen window")
    func gatherSkipsFullscreen() {
        var state = StateCoordinator()
        state.apply(
            .displaysChanged([
                Display(
                    id: DisplayID(1),
                    name: "Main",
                    frame: CGRect(
                        x: 0,
                        y: 0,
                        width: 1920,
                        height: 1080
                    )
                )
            ])
        )
        func tracked(_ id: WindowID) -> ManagedWindow {
            ManagedWindow(
                id: id,
                pid: pid_t(id.raw),
                appName: "App\(id.raw)",
                frame: CGRect(
                    x: 10,
                    y: 10,
                    width: 400,
                    height: 300
                )
            )
        }
        state.apply(.windowCreated(tracked(w1)))
        state.apply(.windowCreated(tracked(w2)))
        state.apply(
            .windowFullscreenChanged(w2, isFullscreen: true)
        )
        let gathered = WindowGather.collect(
            state: state,
            primaryHeight: 1080
        ).flatMap(\.windows)
        // Control arm in the same fixture: the plain window IS
        // gathered, so the skip below is the guard passing.
        #expect(gathered.contains(w1))
        #expect(!gathered.contains(w2))
    }
}
