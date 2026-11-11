import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `focus_space_last` (#3206): a ⌘⇥-style toggle between the last
/// two Spaces, an ordinary arrival, under both history kinds.
@Suite("Space last verb (#3206)", .serialized)
@MainActor
struct SpaceLastVerbTests {
    private static let displayA = DisplayID(1)
    private static let displayB = DisplayID(2)

    /// Spaces 1–3 on display A and 7–8 on display B, a window in
    /// each; Space `shown` active.
    private func makeCore(shown: String = "1") -> KiwiCore {
        let core = makeTestCore()
        let spaces: [(String, DisplayID)] = [
            ("1", Self.displayA), ("2", Self.displayA),
            ("3", Self.displayA), ("7", Self.displayB),
            ("8", Self.displayB),
        ]
        for (index, display) in [Self.displayA, Self.displayB]
            .enumerated()
        {
            core.state.workspaces.upsertDisplay(
                Display(
                    id: display,
                    name: "D\(index)",
                    frame: CGRect(
                        x: 1600 * CGFloat(index),
                        y: 0,
                        width: 1600,
                        height: 1000
                    )
                )
            )
        }
        for (index, (raw, display)) in spaces.enumerated() {
            core.state.workspaces.assign(SpaceID(raw), to: display)
            let id = WindowID(UInt32(index + 1))
            core.state.windows.upsert(
                ManagedWindow(id: id, pid: pid_t(index + 1), appName: raw)
            )
            core.state.workspaces.add(id, to: SpaceID(raw))
            core.state.workspaces.focus(id, in: SpaceID(raw))
        }
        core.execute("focus_space", args: [.string(shown)])
        return core
    }

    private func shown(_ core: KiwiCore) -> String? {
        core.state.workspaces.activeSpace?.raw
    }

    private func run(_ core: KiwiCore, _ verb: String) -> Bool {
        core.execute(verb, args: []).isSuccess
    }

    @Test("per screen: toggles between the last two Spaces")
    func togglesPerScreen() {
        let core = makeCore(shown: "1")
        core.execute("focus_space", args: [.string("3")])
        #expect(core.spaceHistory.kind == .perScreen)
        for expected in ["1", "3", "1", "3"] {
            #expect(run(core, "focus_space_last"))
            #expect(shown(core) == expected)
        }
    }

    @Test("all screens: toggles across screens")
    func togglesAllScreens() {
        let core = makeCore(shown: "1")
        core.execute("set_space_history", args: [.string("all_screens")])
        core.execute("focus_space", args: [.string("7")])
        #expect(run(core, "focus_space_last"))
        #expect(shown(core) == "1")
        #expect(run(core, "focus_space_last"))
        #expect(shown(core) == "7")
    }

    @Test("after a Back, last returns to the Space the Back left")
    func backThenLast() {
        let core = makeCore(shown: "1")
        core.execute("focus_space", args: [.string("2")])
        core.execute("focus_space", args: [.string("3")])
        #expect(run(core, "focus_space_back"))
        #expect(shown(core) == "2")
        #expect(run(core, "focus_space_last"))
        #expect(shown(core) == "3")
    }

    @Test("an arrival: it clears the forward half")
    func clearsForward() {
        let core = makeCore(shown: "1")
        core.execute("focus_space", args: [.string("2")])
        core.execute("focus_space", args: [.string("3")])
        #expect(run(core, "focus_space_back"))
        #expect(run(core, "focus_space_last"))
        #expect(!run(core, "focus_space_forward"))
    }

    @Test("an arrival, not a cursor move: Forward is gone after it")
    func arrivalNotMove() {
        let core = makeCore(shown: "1")
        core.execute("focus_space", args: [.string("2")])
        core.execute("focus_space", args: [.string("3")])
        #expect(run(core, "focus_space_back"))
        #expect(run(core, "focus_space_back"))
        #expect(run(core, "focus_space_last"))
        #expect(shown(core) == "2")
        // A cursor move onto 2 would keep 3 ahead.
        #expect(!run(core, "focus_space_forward"))
    }

    @Test("a Space shown without an event counts before the toggle")
    func unrecordedArrivalCounts() {
        let core = makeCore(shown: "1")
        core.state.workspaces.activate(SpaceID("2"))
        #expect(run(core, "focus_space_last"))
        #expect(shown(core) == "1")
    }

    @Test("a gone or moved last falls back to the nearest entry back")
    func unreachableFallsBack() {
        let core = makeCore(shown: "1")
        core.execute("focus_space", args: [.string("2")])
        core.execute("focus_space", args: [.string("3")])
        core.state.workspaces.assign(SpaceID("2"), to: Self.displayB)
        #expect(run(core, "focus_space_last"))
        #expect(shown(core) == "1")

        // All screens: the per-screen term would skip it anyway.
        let gone = makeCore(shown: "1")
        gone.execute("set_space_history", args: [.string("all_screens")])
        gone.execute("focus_space", args: [.string("2")])
        gone.execute("focus_space", args: [.string("3")])
        gone.state.workspaces.removeSpace(SpaceID("2"))
        #expect(run(gone, "focus_space_last"))
        #expect(shown(gone) == "1")
    }

    @Test("nothing to return to bumps and refuses")
    func refusesAtNothing() {
        let core = makeCore(shown: "1")
        var bumps: [Direction] = []
        core.borders.deadEndProbe = { bumps.append($1) }
        #expect(!run(core, "focus_space_last"))
        #expect(shown(core) == "1")
        #expect(bumps == [.left])
    }
}
