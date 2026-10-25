import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Wrap focus governs the Space step (#2592 ▸ Ruling): under This
/// screen and All screens `focus_space_next` / `_previous` go round
/// the focused screen's Space order and never cross to another
/// screen; Off stops at the ends with the bump. The slide plays in
/// the key's direction, so last → first slides forward.
@Suite("Next and previous Space wrap (#2592)", .serialized)
@MainActor
struct SpaceWrapTests {
    private static let displayA = DisplayID(1)
    private static let displayB = DisplayID(2)

    /// Spaces 1, 2, 4, 5 on display A and 3, 6 on display B — the
    /// ruling's interleaved numbering — a window in each; Space
    /// `shown` active.
    private func makeCore(shown: String) -> KiwiCore {
        let core = makeTestCore()
        let spaces: [(String, DisplayID)] = [
            ("1", Self.displayA), ("2", Self.displayA),
            ("3", Self.displayB), ("4", Self.displayA),
            ("5", Self.displayA), ("6", Self.displayB),
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

    @Test(
        "both wrapping values go round the screen's own Spaces",
        arguments: ["all_screens", "this_screen"]
    )
    func wrapsOnTheScreen(mode: String) {
        let core = makeCore(shown: "5")
        core.execute("set_focus_wrap", args: [.string(mode)])
        var bumps = 0
        core.borders.deadEndProbe = { _, _ in bumps += 1 }
        // 5 is the last on its screen: next goes to 1, never to 6.
        #expect(run(core, "focus_space_next"))
        #expect(shown(core) == "1")
        #expect(run(core, "focus_space_previous"))
        #expect(shown(core) == "5")
        #expect(core.state.workspaces.activeSpace(on: Self.displayB) == "3")
        // The other screen goes round its own two.
        core.execute("focus_space", args: [.string("6")])
        #expect(run(core, "focus_space_next"))
        #expect(shown(core) == "3")
        #expect(bumps == 0)
    }

    @Test("the default wraps")
    func defaultWraps() {
        let core = makeCore(shown: "5")
        #expect(core.focusWrap.mode != .off)
        #expect(run(core, "focus_space_next"))
        #expect(shown(core) == "1")
    }

    @Test("Off stops at the last Space with the bump")
    func offBumps() {
        let core = makeCore(shown: "5")
        core.execute("set_focus_wrap", args: [.string("off")])
        var bumps: [Direction] = []
        core.borders.deadEndProbe = { bumps.append($1) }
        #expect(!run(core, "focus_space_next"))
        #expect(shown(core) == "5")
        #expect(bumps == [.right])
    }

    @Test("a screen with one Space does not wrap onto itself")
    func lonelySpaceBumps() {
        let core = makeCore(shown: "6")
        core.state.workspaces.assign(SpaceID("3"), to: Self.displayA)
        var bumps = 0
        core.borders.deadEndProbe = { _, _ in bumps += 1 }
        #expect(!run(core, "focus_space_next"))
        #expect(shown(core) == "6")
        #expect(bumps == 1)
    }

    /// The slide follows the key, never the order: last → first is a
    /// step forward even though the order runs backward.
    @Test("a wrapped step slides in the key's direction")
    func slideFollowsTheKey() throws {
        let core = makeCore(shown: "5")
        let order = core.state.workspaces.order
        let forward = try #require(
            core.spaceSlideIntent(to: SpaceID("1"), step: 1)
        )
        #expect(forward.direction(to: SpaceID("1"), order: order) == 1)
        let backward = try #require(
            core.spaceSlideIntent(to: SpaceID("1"), step: -1)
        )
        #expect(backward.direction(to: SpaceID("1"), order: order) == -1)
        // No step: the order decides, as a click on the bar does.
        let picked = try #require(core.spaceSlideIntent(to: SpaceID("1")))
        #expect(picked.direction(to: SpaceID("1"), order: order) == -1)
    }
}
