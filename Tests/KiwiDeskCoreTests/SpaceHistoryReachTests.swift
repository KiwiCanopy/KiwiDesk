import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Space history's two quieter arms (#1655 review): a Space
/// shown with no event is still a visit, through the retile's
/// hook, and Back skips an entry whose Space has gone or — per
/// screen — now lives on another screen.
@Suite("Space history reach (#1655)", .serialized)
@MainActor
struct SpaceHistoryReachTests {
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

    @Test("a Space shown without an event is a visit")
    func retileRecordsTheVisit() {
        let core = makeCore(shown: "1")
        core.state.workspaces.activate(SpaceID("2"))
        core.retile()
        core.state.workspaces.activate(SpaceID("3"))
        #expect(run(core, "focus_space_back"))
        #expect(shown(core) == "2")
    }

    @Test("Back skips a Space that left state")
    func goneSpaceIsSkipped() {
        let core = makeCore(shown: "1")
        core.execute("focus_space", args: [.string("2")])
        core.execute("focus_space", args: [.string("3")])
        core.state.workspaces.removeSpace(SpaceID("2"))
        #expect(run(core, "focus_space_back"))
        #expect(shown(core) == "1")
    }

    @Test("per screen, Back skips a Space now on another screen")
    func movedSpaceIsSkipped() {
        let core = makeCore(shown: "1")
        core.execute("focus_space", args: [.string("2")])
        core.execute("focus_space", args: [.string("3")])
        core.state.workspaces.assign(SpaceID("2"), to: Self.displayB)
        #expect(run(core, "focus_space_back"))
        #expect(shown(core) == "1")
    }
}
