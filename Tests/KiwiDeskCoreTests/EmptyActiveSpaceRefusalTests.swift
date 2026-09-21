import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The #292 preflight's "no focus anchor" clause names an EMPTY
/// ACTIVE Space when that is why the anchor is missing (#1336):
/// after `move_to_desktop` and `focus_desktop` the window
/// `get_state` marks focused sits in a Space that is not active,
/// so "no managed window is currently focused" named the wrong
/// fact. The refusal says which Space is empty, where the marked
/// window is, and the `focus_space` that brings it under the
/// verb — the same sentence on the log and the response.
@Suite("An empty active Space names itself (#1336)", .serialized)
@MainActor
struct EmptyActiveSpaceRefusalTests {
    private static let displayA = DisplayID(1)
    private static let displayB = DisplayID(2)

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-empty-space-\(UUID().uuidString)"
                )
        )
        return core
    }

    private func addWindow(
        _ core: KiwiCore,
        _ raw: UInt32,
        pid: pid_t,
        app: String = "App"
    ) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(raw), pid: pid, appName: app)
            )
        )
    }

    /// Pins one screen so the fixture states the display the
    /// same-screen clause reads (tests.md, #531).
    private func pinDisplay(
        _ core: KiwiCore,
        _ id: DisplayID,
        spaces: [String]
    ) {
        core.state.workspaces.upsertDisplay(
            Display(
                id: id,
                name: "\(id.raw)",
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        )
        for space in spaces {
            core.state.workspaces.assign(SpaceID(space), to: id)
        }
    }

    /// The device shape (owner, 2026-09-08): the window marked
    /// focused in Space 1, the ACTIVE Space 2 empty.
    private func arriveOnEmptySpace(
        _ core: KiwiCore,
        pid: pid_t
    ) {
        addWindow(core, 1, pid: pid, app: "Finder")
        core.execute("focus_space", args: [.string("2")])
        pinDisplay(core, Self.displayA, spaces: ["1", "2"])
        #expect(core.activeSpace?.id == SpaceID("2"))
        #expect(core.focusedWindowID == nil)
        #expect(core.state.workspaces[SpaceID("1")]?.focused == WindowID(1))
    }

    @Test("The refusal names the empty Space and the marked window")
    func refusalNamesTheEmptySpace() {
        let core = makeCore()
        var logs: [String] = []
        core.onLog = { logs.append($0) }
        arriveOnEmptySpace(core, pid: 1)
        core.frontmostPIDProvider = { 1 }
        let response = core.execute(
            "move_to_desktop",
            args: [.number(1)]
        )
        #expect(!response.isSuccess)
        #expect(
            response.error
                == "the active Space 2 is empty; the focused window "
                + "(Finder) is in Space 1 — focus_space 1 first"
        )
        // The log carries the same sentence, under the clause
        // that fired, so a trace reads as the response does.
        #expect(
            logs.contains {
                $0.contains("denied move_to_desktop — anchor none, ")
                    && $0.contains(
                        "no focus anchor — the active Space 2 is empty"
                    )
            }
        )
    }

    /// The follow twin declines through the same clause with
    /// the same sentence — the two verbs never disagree about
    /// how to decline (owner, 2026-09-08).
    @Test("The follow verb declines with the same sentence")
    func followDeclinesAlike() {
        let core = makeCore()
        arriveOnEmptySpace(core, pid: 1)
        core.frontmostPIDProvider = { 1 }
        let response = core.execute(
            "move_to_desktop_and_follow",
            args: [.number(1)]
        )
        #expect(!response.isSuccess)
        #expect(
            response.error?.hasPrefix("the active Space 2 is empty; ")
                == true
        )
    }

    /// The recovery the refusal names: once the Space holding
    /// the window is active, the preflight lets the verb through.
    @Test("focus_space on the named Space lifts the refusal")
    func focusSpaceLiftsTheRefusal() {
        let core = makeCore()
        var logs: [String] = []
        core.onLog = { logs.append($0) }
        let pid = getpid()
        arriveOnEmptySpace(core, pid: pid)
        guard let observer = AXApplicationObserver(pid: pid) else {
            Issue.record("could not create a self AX observer")
            return
        }
        core.eventLoop.observers[pid] = observer
        core.frontmostPIDProvider = { pid }
        core.execute("focus_space", args: [.string("1")])
        logs.removeAll()
        let response = core.execute(
            "move_to_desktop",
            args: [.number(1)]
        )
        // The verb itself may refuse (no Desktop bridge in a unit
        // test); the preflight no longer does.
        #expect(
            response.error?.hasPrefix("the active Space") != true
        )
        #expect(!logs.contains { $0.contains("preflight (#292)") })
    }

    /// An active Space with members but no focus slot is the
    /// generic clause: nothing is parked elsewhere for the user
    /// to see, so the limitations table's sentence stands.
    @Test("A populated Space without a focus keeps the generic sentence")
    func populatedSpaceKeepsGeneric() {
        let core = makeCore()
        var logs: [String] = []
        core.onLog = { logs.append($0) }
        addWindow(core, 1, pid: 1)
        // A bare re-add clears the focus slot and `lastFocused`
        // while the member stays.
        core.state.workspaces.add(WindowID(1), to: SpaceID("1"))
        #expect(core.focusedWindowID == nil)
        #expect(core.activeSpace?.windows == [WindowID(1)])
        core.frontmostPIDProvider = { 1 }
        let response = core.execute(
            "move_to_desktop",
            args: [.number(1)]
        )
        #expect(
            response.error == "no managed window is currently focused"
        )
        #expect(
            logs.contains {
                $0.hasSuffix("anchor none, no focus anchor")
            }
        )
    }

    /// An empty active Space with nothing marked anywhere says
    /// only that it is empty.
    @Test("An empty Space with no marked window names no recovery")
    func emptySpaceAloneNamesNoRecovery() {
        let core = makeCore()
        core.execute("focus_space", args: [.string("2")])
        core.frontmostPIDProvider = { 1 }
        let response = core.execute(
            "move_to_desktop",
            args: [.number(1)]
        )
        #expect(response.error == "the active Space 2 is empty")
    }

    /// A Space on ANOTHER screen lays its windows out there, so
    /// its focused member is never the window the user sees
    /// parked on this one.
    @Test("A Space on another screen is never named")
    func otherScreenSpaceIsNeverNamed() {
        let core = makeCore()
        addWindow(core, 1, pid: 1, app: "Finder")
        core.execute("focus_space", args: [.string("2")])
        pinDisplay(core, Self.displayA, spaces: ["2"])
        pinDisplay(core, Self.displayB, spaces: ["1"])
        core.frontmostPIDProvider = { 1 }
        let response = core.execute(
            "move_to_desktop",
            args: [.number(1)]
        )
        #expect(response.error == "the active Space 2 is empty")
    }

    /// Two sibling Spaces each marking a focus: the one holding
    /// `lastFocused` — the window that last held the system focus
    /// — is the one named.
    @Test("lastFocused's Space outranks another marked Space")
    func lastFocusedSpaceOutranks() {
        let core = makeCore()
        addWindow(core, 1, pid: 1, app: "Finder")
        addWindow(core, 2, pid: 2, app: "Mail")
        core.moveWindow(WindowID(2), to: SpaceID("3"), follow: false)
        // Space 1 marks 1, Space 3 marks 2; the last honored
        // focus is window 1.
        core.state.workspaces.focus(WindowID(1), in: SpaceID("1"))
        core.execute("focus_space", args: [.string("2")])
        pinDisplay(core, Self.displayA, spaces: ["1", "2", "3"])
        #expect(core.state.workspaces.lastFocused == WindowID(1))
        core.frontmostPIDProvider = { 1 }
        let response = core.execute(
            "move_to_desktop",
            args: [.number(1)]
        )
        #expect(
            response.error
                == "the active Space 2 is empty; the focused window "
                + "(Finder) is in Space 1 — focus_space 1 first"
        )
    }
}
