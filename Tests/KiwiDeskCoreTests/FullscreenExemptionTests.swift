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
            state.effectiveMembers(of: home).contains(w2)
        )
        #expect(
            !state.effectiveMembers(of: away).contains(w2)
        )
    }

    @Test("A floating fullscreen sticky never travels either")
    func floatingFullscreenStickyStaysHome() {
        var state = makeState()
        state.workspaces.ensureSpace(SpaceID(2))
        state.setSticky(w2, .global)
        state.apply(.windowFloatChanged(w2, isFloating: true))
        state.apply(
            .windowFullscreenChanged(w2, isFullscreen: true)
        )
        state.workspaces.activate(SpaceID(2))
        // The floating-traveler append is a separate path from
        // the tiled injection — without its own fullscreen
        // exclusion the render space grows a second glyph
        // (guard-prover found the tiled fixture never reaches
        // that filter's fullscreen term).
        let home = state.workspaces[SpaceID(1)]!
        let away = state.workspaces[SpaceID(2)]!
        #expect(
            state.effectiveMembers(of: home).contains(w2)
        )
        #expect(
            !state.effectiveMembers(of: away).contains(w2)
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

    @Test("The re-pick steps forward, not to the array head")
    func rePickPrefersForwardNeighbor() {
        var state = StateCoordinator()
        let w4 = WindowID(4)
        for id in [w1, w2, w3, w4] {
            state.apply(.windowCreated(makeWindow(id)))
        }
        let space = state.workspaces.activeSpace!
        state.workspaces.focus(w2, in: space)
        state.apply(
            .windowFullscreenChanged(w3, isFullscreen: true)
        )
        state.apply(.windowDestroyed(w2, wasMinimized: false))
        // [w1, w3fs, w4] with the removed slot at index 1:
        // forward past the fullscreen member lands w4 — the
        // array head (w1) would be the #11 cross-row yank.
        #expect(state.workspaces[space]?.focused == w4)
    }

    @Test("The re-pick falls back to the backward neighbor")
    func rePickFallsBackBackward() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(w1)))
        state.apply(.windowCreated(makeWindow(w2)))
        state.apply(.windowCreated(makeWindow(w3)))
        let space = state.workspaces.activeSpace!
        state.workspaces.focus(w3, in: space)
        state.apply(
            .windowFullscreenChanged(w2, isFullscreen: true)
        )
        state.apply(.windowDestroyed(w3, wasMinimized: false))
        // Nothing forward of the removed last slot: backward
        // past the fullscreen member lands w1.
        #expect(state.workspaces[space]?.focused == w1)
    }

    @Test("A close elsewhere never moves a held fullscreen focus")
    func unrelatedCloseKeepsFullscreenFocus() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(w1)))
        state.apply(.windowCreated(makeWindow(w2)))
        let space = state.workspaces.activeSpace!
        state.workspaces.focus(w2, in: space)
        state.apply(
            .windowFullscreenChanged(w2, isFullscreen: true)
        )
        // The user is inside w2's fullscreen Space; closing an
        // unrelated window must not silently reassign the
        // focused slot behind them.
        state.apply(.windowDestroyed(w1, wasMinimized: false))
        #expect(state.workspaces[space]?.focused == w2)
    }
}

/// Track occupancy: fill-then-spill counts only members the
/// layout will actually place — a fullscreen member fills no
/// slot, so a spawn joins its track instead of spilling (#670
/// re-review: reachable purely in state, so it owes its red).
@Suite("Fullscreen track occupancy (#670)")
struct FullscreenTrackOccupancyTests {
    @Test("A spawn's occupancy count skips a fullscreen member")
    func spawnJoinsPastFullscreenMember() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(w1)))
        state.apply(.windowCreated(makeWindow(w2)))
        let space = state.workspaces.activeSpace!
        state.workspaces.withSpace(space) { $0.mode = .track }
        state.trackCapacities[space] = 2
        state.apply(
            .windowFullscreenChanged(w2, isFullscreen: true)
        )
        state.apply(.windowCreated(makeWindow(w3)))
        // Occupancy 1 (w2 is exempt) < capacity 2: w3 JOINS the
        // track at its head (`new_window_position` default
        // `.first`), landing at index 0. Counting w2 would
        // spill it into a new track appended after the focused
        // one instead — the order is the probe; the break
        // marker is not (a head join transfers it too).
        #expect(
            state.workspaces[space]?.windows == [w3, w1, w2]
        )
    }

    @Test("A full track still spills (the count stays live)")
    func fullTrackStillSpills() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(w1)))
        state.apply(.windowCreated(makeWindow(w2)))
        let space = state.workspaces.activeSpace!
        state.workspaces.withSpace(space) { $0.mode = .track }
        state.trackCapacities[space] = 2
        state.apply(.windowCreated(makeWindow(w3)))
        // Control arm: two placeable members meet capacity 2,
        // so the spill fires and w3 opens a new track after the
        // focused one (an append) — proving the fixture reaches
        // the occupancy count at all.
        #expect(
            state.workspaces[space]?.windows == [w1, w2, w3]
        )
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
