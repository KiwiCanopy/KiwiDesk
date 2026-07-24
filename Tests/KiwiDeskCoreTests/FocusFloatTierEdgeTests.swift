import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-floatedge-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: dir)
}

@MainActor
private func spawn(_ core: KiwiCore, count: Int) {
    for id in 1...count {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(UInt32(id)),
                    pid: 1,
                    appName: "A"
                )
            )
        )
    }
}

/// Floats `id` and parks its live frame at `frame`.
@MainActor
private func float(
    _ core: KiwiCore,
    _ id: WindowID,
    at frame: CGRect
) {
    core.state.windows.setFloating(id, true)
    core.state.apply(.windowMoved(id, frame))
}

/// Directional `focus` from `origin`; the landing window, or
/// nil on a dead end. Focus is re-pinned before each probe.
@MainActor
private func step(
    _ core: KiwiCore,
    space: SpaceID,
    from origin: WindowID,
    _ direction: String
) -> WindowID? {
    core.state.workspaces.focus(origin, in: space)
    guard
        core.execute("focus", args: [.string(direction)])
            .isSuccess
    else { return nil }
    return core.activeSpace?.focused
}

/// The float tier's fall-through seams the main suite doesn't
/// cover: scrolling and monocle edges, a floating-mode space,
/// the zero-frame guard, and an end-to-end floating sticky
/// traveler (#488 review round 1).
@Suite("Focus float tier edges (#488)", .serialized)
@MainActor
struct FocusFloatTierEdgeTests {
    @Test("Scrolling: a non-wrapping row end reaches a float")
    func scrollingEndReachesFloat() {
        let core = makeCore()
        spawn(core, count: 3)
        core.execute(
            "set_mode",
            args: [.string("1"), .string("scrolling")]
        )
        let space = SpaceID("1")
        // Float first, THEN read w2's settled slot — floating
        // w3 retiles the row and moves the trailing edge.
        core.state.windows.setFloating(WindowID(3), true)
        let slots = core.tiler.calculatedFrames(
            state: core.state
        )
        let last = slots[WindowID(2)]!
        // Park w3 past the row's trailing end.
        core.state.apply(
            .windowMoved(
                WindowID(3),
                CGRect(
                    x: last.maxX + 40,
                    y: last.midY - 100,
                    width: 240,
                    height: 200
                )
            )
        )
        // w2 is the last tiled window; a step past the end
        // falls through the array step AND the tiled geometric
        // search into the float tier.
        #expect(
            step(core, space: space, from: WindowID(2), "right")
                == WindowID(3)
        )
    }

    @Test("Monocle: the cross axis reaches a parked float")
    func monocleCrossAxisReachesFloat() {
        let core = makeCore()
        spawn(core, count: 3)
        core.execute(
            "set_mode",
            args: [.string("1"), .string("monocle")]
        )
        core.execute(
            "monocle.set_orientation",
            args: [.string("horizontal")]
        )
        let space = SpaceID("1")
        let slots = core.tiler.calculatedFrames(
            state: core.state
        )
        let shared = slots[WindowID(1)]!
        // Park w3 above the shared monocle frame.
        float(
            core,
            WindowID(3),
            at: CGRect(
                x: shared.midX - 100,
                y: shared.minY - 260,
                width: 200,
                height: 240
            )
        )
        // Up is cross-axis: monocleCycle falls through, the
        // tiled search ties on the shared frame (zero forward
        // offset), and the float tier answers.
        #expect(
            step(core, space: space, from: WindowID(1), "up")
                == WindowID(3)
        )
    }

    @Test("A zero-frame float is never a candidate")
    func zeroFrameFloatExcluded() {
        let core = makeCore()
        spawn(core, count: 2)
        core.execute(
            "track.set_new_window",
            args: [.string("own_track")]
        )
        core.execute(
            "set_mode",
            args: [.string("1"), .string("track")]
        )
        let space = SpaceID("1")
        // Float w2 but leave its live frame at .zero — a window
        // whose frame was never observed. It must not become a
        // spurious up/left candidate at the origin.
        core.state.windows.setFloating(WindowID(2), true)
        #expect(
            step(core, space: space, from: WindowID(1), "left")
                == nil
        )
        #expect(
            step(core, space: space, from: WindowID(1), "up")
                == nil
        )
    }

    @Test("A floating sticky traveler is reachable end to end")
    func travelerReachableEndToEnd() {
        let core = makeCore()
        spawn(core, count: 1)
        core.execute(
            "set_mode",
            args: [.string("1"), .string("track")]
        )
        let space = SpaceID("1")
        let slots = core.tiler.calculatedFrames(
            state: core.state
        )
        let slot = slots[WindowID(1)]!
        // w50: floating GLOBAL sticky homed on space 2, parked
        // right of the only tile — it travels into the active
        // space's float tier.
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(50),
                pid: 1,
                appName: "A",
                frame: CGRect(
                    x: slot.maxX + 40,
                    y: slot.midY - 100,
                    width: 240,
                    height: 200
                ),
                isFloating: true,
                stickyScope: .global
            )
        )
        core.state.workspaces.add(WindowID(50), to: SpaceID("2"))
        core.state.workspaces.focus(WindowID(1), in: space)
        #expect(
            core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        // A traveler never becomes the membership-guarded
        // `space.focused` slot (#431) — the anchor is the
        // honest landing assert.
        #expect(
            core.state.workspaces.lastFocused == WindowID(50)
        )
        let active = core.activeSpace!
        #expect(
            core.state.focusAnchor(of: active) == WindowID(50)
        )
    }

    @Test("A floating-mode space navigates by live frames")
    func floatingModeSpaceNavigates() {
        let core = makeCore()
        spawn(core, count: 3)
        core.execute(
            "set_mode",
            args: [.string("1"), .string("floating")]
        )
        let space = SpaceID("1")
        // Three side-by-side live frames; w3 additionally
        // carries the float flag (members of a floating-mode
        // space are not auto-flagged).
        for (index, id) in [1, 2, 3].enumerated() {
            core.state.apply(
                .windowMoved(
                    WindowID(UInt32(id)),
                    CGRect(
                        x: 100 + CGFloat(index) * 300,
                        y: 100,
                        width: 260,
                        height: 200
                    )
                )
            )
        }
        core.state.windows.setFloating(WindowID(3), true)
        // Unflagged members navigate on the tiled tier via the
        // slot→frame fallback...
        #expect(
            step(core, space: space, from: WindowID(1), "right")
                == WindowID(2)
        )
        // ...and the flagged float is reached via the float
        // tier once the tiled candidates run out.
        #expect(
            step(core, space: space, from: WindowID(2), "right")
                == WindowID(3)
        )
        #expect(
            step(core, space: space, from: WindowID(3), "left")
                == WindowID(2)
        )
    }
}

/// The `.display`-sticky drop branch of the float tier's
/// membership — the one case where `stickyRenderSpace` actually
/// diverges from the queried space (#488 review round 1). Pure
/// state, fake displays; the DisplayStickyRenderTests pattern.
@Suite("Float-tier display-sticky drop (#488)")
struct FloatTierDisplayStickyTests {
    @Test("A display-sticky float rendering elsewhere is dropped")
    func renderElsewhereDropped() {
        var state = StateCoordinator()
        state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "A",
                frame: CGRect(
                    x: 0,
                    y: 0,
                    width: 1920,
                    height: 1080
                )
            )
        )
        for id in ["1", "2"] {
            state.workspaces.ensureSpace(SpaceID(id))
            state.workspaces.assign(
                SpaceID(id),
                to: DisplayID(1)
            )
        }
        // w1: floating DISPLAY sticky homed on space 1. Space 2
        // is the display's shown space, so w1 renders there.
        state.windows.upsert(
            ManagedWindow(
                id: WindowID(1),
                pid: 1,
                appName: "S",
                frame: CGRect(
                    x: 10,
                    y: 10,
                    width: 100,
                    height: 100
                ),
                isFloating: true,
                stickyScope: .display
            )
        )
        state.workspaces.add(WindowID(1), to: SpaceID("1"))
        state.workspaces.activate(SpaceID("2"))
        let home = state.workspaces[SpaceID("1")]!
        let shown = state.workspaces[SpaceID("2")]!
        // Dropped from its home space's candidates (it has
        // physically traveled away)...
        #expect(
            state.floatingFocusCandidates(of: home) == []
        )
        // ...and offered on the space it renders on.
        #expect(
            state.floatingFocusCandidates(of: shown)
                == [WindowID(1)]
        )
    }
}
