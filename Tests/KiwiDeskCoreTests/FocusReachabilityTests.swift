import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-reach-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: dir)
}

/// Spawns `count` same-app windows (the device-QA shape) into
/// the default space.
@MainActor
private func spawn(_ core: KiwiCore, count: Int) {
    for index in 1...count {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(UInt32(index)),
                    pid: 1,
                    appName: "A"
                )
            )
        )
    }
}

/// Where a directional `focus` lands from `origin`, or nil on a
/// dead end. Focus is re-pinned before each probe so probes are
/// independent of each other.
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

/// Every window reachable from `start` by chained directional
/// `focus` presses — BFS over all four directions.
@MainActor
private func reachable(
    _ core: KiwiCore,
    space: SpaceID,
    from start: WindowID
) -> Set<WindowID> {
    var seen: Set<WindowID> = [start]
    var queue: [WindowID] = [start]
    while let origin = queue.popLast() {
        for direction in ["left", "right", "up", "down"] {
            if let next = step(
                core,
                space: space,
                from: origin,
                direction
            ), !seen.contains(next) {
                seen.insert(next)
                queue.append(next)
            }
        }
    }
    return seen
}

/// #488 owner repro, bsp: w1 the left half, w2 the top right,
/// w3/w4 the bottom-right pair. `alternating` picks the split
/// axis from depth alone, so the shape is screen-independent —
/// but only above the pile threshold. Directional focus must
/// reach every window from every other.
@Suite("BSP focus reachability (#488)", .serialized)
@MainActor
struct BspFocusReachabilityTests {
    private func makeBsp(_ core: KiwiCore) -> SpaceID {
        core.execute(
            "set_mode",
            args: [.string("1"), .string("bsp")]
        )
        core.execute(
            "bsp.set_strategy",
            args: [.string("alternating")]
        )
        // These frames come off the host's real NSScreen, so the
        // default 300pt minimum makes the arrangement depend on
        // how wide that screen is: the bottom-right region is a
        // quarter of it, and below 2 * min BspLayout correctly
        // falls back to an OverlapStack pile (#383/#44) instead
        // of the side-by-side pair asserted below. A CI runner's
        // ~1066pt display lands under that threshold. Pin a
        // minimum no plausible display can breach — the pile
        // fallback has its own coverage, and is not the subject
        // here.
        core.execute(
            "set_min_window_size",
            args: [.number(100)]
        )
        spawn(core, count: 4)
        return SpaceID("1")
    }

    @Test("The fixture builds the reported arrangement")
    func arrangement() {
        let core = makeCore()
        _ = makeBsp(core)
        let slots = core.tiler.calculatedFrames(
            state: core.state
        )
        let w1 = slots[WindowID(1)]!
        let w2 = slots[WindowID(2)]!
        let w3 = slots[WindowID(3)]!
        let w4 = slots[WindowID(4)]!
        // w1 the full-height left half.
        #expect(w1.minX < w2.minX)
        #expect(w1.height > w2.height)
        // w2 above the bottom pair (AX coords, y down).
        #expect(w2.midY < w3.midY)
        #expect(w2.midY < w4.midY)
        // w3 left of w4 along the bottom.
        #expect(w3.minX < w4.minX)
        #expect(abs(w3.midY - w4.midY) < 1)
    }

    @Test("Every window is reachable from every other")
    func fullReachability() {
        let core = makeCore()
        let space = makeBsp(core)
        let all = Set((1...4).map { WindowID(UInt32($0)) })
        for start in all {
            #expect(
                reachable(core, space: space, from: start)
                    == all,
                "unreachable windows from \(start)"
            )
        }
    }

    @Test("focus up from the bottom pair reaches the top right")
    func upReachesTopRight() {
        let core = makeCore()
        let space = makeBsp(core)
        #expect(
            step(core, space: space, from: WindowID(3), "up")
                == WindowID(2)
        )
        #expect(
            step(core, space: space, from: WindowID(4), "up")
                == WindowID(2)
        )
    }
}

/// #488 owner repro, track: four tracks side by side. Both
/// readings of "side by side" are covered — four single-window
/// columns (vertical axis) and one horizontal-axis track whose
/// four full-height windows LOOK like columns.
@Suite("Track focus reachability (#488)", .serialized)
@MainActor
struct TrackFocusReachabilityTests {
    /// Four single-window tracks (own_track seeds one window
    /// per track on mode entry; #437's default would pack them).
    private func makeColumns(_ core: KiwiCore) -> SpaceID {
        spawn(core, count: 4)
        core.execute(
            "track.set_new_window",
            args: [.string("own_track")]
        )
        core.execute(
            "set_mode",
            args: [.string("1"), .string("track")]
        )
        return SpaceID("1")
    }

    /// One horizontal-axis track holding all four windows side
    /// by side.
    private func makeRow(_ core: KiwiCore) -> SpaceID {
        spawn(core, count: 4)
        core.execute(
            "set_mode",
            args: [.string("1"), .string("track")]
        )
        core.execute(
            "track.set_axis",
            args: [.string("horizontal")]
        )
        let space = SpaceID("1")
        core.state.workspaces.withSpace(space) {
            $0.trackBreaks = [WindowID(1)]
        }
        return space
    }

    @Test("Columns: every window reachable from every other")
    func columnsFullReachability() {
        let core = makeCore()
        let space = makeColumns(core)
        let all = Set((1...4).map { WindowID(UInt32($0)) })
        for start in all {
            #expect(
                reachable(core, space: space, from: start)
                    == all,
                "unreachable windows from \(start)"
            )
        }
    }

    @Test("Columns: focus right walks every track in order")
    func columnsWalkRight() {
        let core = makeCore()
        let space = makeColumns(core)
        for id in 1...3 {
            #expect(
                step(
                    core,
                    space: space,
                    from: WindowID(UInt32(id)),
                    "right"
                ) == WindowID(UInt32(id + 1))
            )
        }
    }

    @Test("Row: every window reachable from every other")
    func rowFullReachability() {
        let core = makeCore()
        let space = makeRow(core)
        let all = Set((1...4).map { WindowID(UInt32($0)) })
        for start in all {
            #expect(
                reachable(core, space: space, from: start)
                    == all,
                "unreachable windows from \(start)"
            )
        }
    }

    @Test("Row: focus right walks every window in order")
    func rowWalkRight() {
        let core = makeCore()
        let space = makeRow(core)
        for id in 1...3 {
            #expect(
                step(
                    core,
                    space: space,
                    from: WindowID(UInt32(id)),
                    "right"
                ) == WindowID(UInt32(id + 1))
            )
        }
    }
}
