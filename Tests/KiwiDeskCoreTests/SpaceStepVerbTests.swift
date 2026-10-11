import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The four Space step verbs (#1655, rulings 2026-10-09):
/// `focus_space_previous` / `_next` step the focused screen's
/// order; `focus_space_back` / `_forward` walk the history the
/// `space_history` setting names. Every arrival is a visit; none
/// of them creates a Space; an end refuses with the row-end bump.
@Suite("Space step and history verbs (#1655)", .serialized)
@MainActor
struct SpaceStepVerbTests {
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

    @Test("previous and next step the focused screen, ends bump")
    func orderStep() {
        let core = makeCore(shown: "2")
        var bumps: [Direction] = []
        core.borders.deadEndProbe = { bumps.append($1) }
        #expect(run(core, "focus_space_next"))
        #expect(shown(core) == "3")
        #expect(!run(core, "focus_space_next"))
        #expect(shown(core) == "3")
        #expect(bumps == [.right])
        #expect(run(core, "focus_space_previous"))
        #expect(run(core, "focus_space_previous"))
        #expect(!run(core, "focus_space_previous"))
        #expect(shown(core) == "1")
        #expect(bumps == [.right, .left])
        // The focused screen's order, never the other screen's.
        core.execute("focus_space", args: [.string("7")])
        #expect(run(core, "focus_space_next"))
        #expect(shown(core) == "8")
        #expect(core.state.workspaces.activeSpace(on: Self.displayA) == "1")
    }

    @Test("back and forward walk the visits, per screen")
    func historyPerScreen() {
        let core = makeCore(shown: "1")
        core.execute("focus_space", args: [.string("3")])
        core.execute("focus_space", args: [.string("2")])
        #expect(core.spaceHistory.kind == .perScreen)
        #expect(run(core, "focus_space_back"))
        #expect(shown(core) == "3")
        #expect(run(core, "focus_space_back"))
        #expect(shown(core) == "1")
        var bumps: [Direction] = []
        core.borders.deadEndProbe = { bumps.append($1) }
        #expect(!run(core, "focus_space_back"))
        #expect(bumps == [.left])
        #expect(run(core, "focus_space_forward"))
        #expect(shown(core) == "3")
        // Another arrival clears the forward half.
        core.execute("focus_space", args: [.string("1")])
        #expect(!run(core, "focus_space_forward"))
        #expect(bumps == [.left, .right])
    }

    @Test("per screen stays on the screen; all screens crosses")
    func kindDecidesTheScreen() {
        let perScreen = makeCore(shown: "1")
        perScreen.execute("focus_space", args: [.string("2")])
        perScreen.execute("focus_space", args: [.string("7")])
        // Display B's own trail holds 7 alone; A's is untouched.
        #expect(!run(perScreen, "focus_space_back"))
        #expect(shown(perScreen) == "7")

        let all = makeCore(shown: "1")
        all.execute("set_space_history", args: [.string("all_screens")])
        all.execute("focus_space", args: [.string("2")])
        all.execute("focus_space", args: [.string("7")])
        #expect(run(all, "focus_space_back"))
        #expect(shown(all) == "2")
    }

    @Test("a move-and-follow is a visit")
    func followCounts() {
        let core = makeCore(shown: "1")
        core.execute(
            "move_to_space_and_follow",
            args: [.string("3"), .number(1)]
        )
        #expect(shown(core) == "3")
        #expect(run(core, "focus_space_back"))
        #expect(shown(core) == "1")
    }

    @Test("a gone Space is skipped, and none is ever created")
    func neverCreates() {
        let core = makeCore(shown: "1")
        core.execute("focus_space", args: [.string("2")])
        core.execute("focus_space", args: [.string("3")])
        core.execute("delete_space", args: [.string("2")])
        let before = core.state.workspaces.allSpaces.map(\.id)
        #expect(run(core, "focus_space_back"))
        #expect(shown(core) == "1")
        #expect(core.state.workspaces[SpaceID("2")] == nil)
        #expect(core.state.workspaces.allSpaces.map(\.id) == before)
    }

    @Test("set_space_history refuses a value it does not know")
    func verbRefuses() {
        let core = makeTestCore()
        let reply = core.execute("set_space_history", args: [.string("x")])
        #expect(!reply.isSuccess, "accepted an unknown kind")
        let message = reply.error ?? ""
        #expect(message.contains("per_screen"))
        #expect(message.contains("all_screens"))
    }

    @Test("a profile's override wins over the base")
    func profileOverrideWins() {
        let core = makeTestCore()
        core.applySpaceHistory(base: .perScreen, profile: .allScreens)
        #expect(core.spaceHistory.kind == .allScreens)
        // The verb writes the base, which the override still beats.
        core.execute("set_space_history", args: [.string("per_screen")])
        #expect(core.spaceHistory.kind == .allScreens)
        core.applySpaceHistory(profile: nil)
        #expect(core.spaceHistory.kind == .perScreen)
    }
}
