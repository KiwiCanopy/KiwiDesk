import Foundation
import Testing

@testable import KiwiDeskCore

/// The arrival focus Jump to window owes (#1875): paid when the
/// window arrives — a Move here filed into the Space it was owed
/// for first — and stood down off that Space, past the bound, or
/// after a press or a commanded focus. Driven through the real
/// fold and the `.windowCreated` arm, on minimized windows, which
/// need no bridge. The verdict is read off the payer's own log
/// line: the fold's new-window grant focuses an arrival in the
/// active Space on its own, so the focus alone cannot tell a
/// payment from a stand-down.
@Suite("Jump to window arrival focus (#1875)", .serialized)
@MainActor
struct JumpFocusTests {
    private let pid: pid_t = 100
    private let bundle = "app.test.notes"
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)
    private let log = Log()

    /// The payer's lines, captured.
    @MainActor
    private final class Log {
        var lines: [String] = []
        var paid: Bool { lines.contains { $0.contains("focus handed") } }
        var stoodDown: Bool {
            lines.contains { $0.contains("focus stood down") }
        }
    }

    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        for space in ["1", "2"] {
            core.state.workspaces.ensureSpace(SpaceID(space))
        }
        core.state.workspaces.activate("1")
        core.wallClock = { self.start }
        core.onLog = { [log] line in log.lines.append(line) }
        core.openOrFocus.deminiaturize = { _, _ in }
        // 1 here, focused; 4 minimized from Space 2.
        track(core, 1, in: "1")
        track(core, 2, in: "2")
        track(core, 4, in: "2")
        core.state.workspaces.focus(WindowID(1), in: "1")
        var effects = AppliedEffects()
        core.state.applyWindowDestroyed(
            WindowID(4),
            wasMinimized: true,
            effects: &effects
        )
        return core
    }

    private func track(_ core: KiwiCore, _ id: UInt32, in space: String) {
        let window = ManagedWindow(
            id: WindowID(id),
            pid: pid,
            appName: "Notes",
            appBundleID: bundle
        )
        core.state.apply(.windowCreated(window))
        core.state.workspaces.add(WindowID(id), to: SpaceID(space))
    }

    private func arrive(_ core: KiwiCore, _ id: UInt32 = 4) {
        core.handle(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(id),
                    pid: pid,
                    appName: "Notes",
                    appBundleID: bundle
                )
            )
        )
    }

    /// The debt ended unpaid, and said so.
    private func expectStoodDown(_ core: KiwiCore) {
        #expect(log.stoodDown)
        #expect(!log.paid)
        #expect(core.jump.owed == nil)
    }

    /// Its app rule files it in Space 2: the arrival moves it here
    /// and focuses it, and nothing is filed ahead of the arrival.
    @Test("Move here files a minimized window here at its arrival")
    func moveHereRelocates() {
        let core = makeCore()
        core.state.appRules[bundle] = "2"
        #expect(core.moveHere(.window(WindowID(4))))
        #expect(core.state.rememberedSpaces[WindowID(4)] == nil)
        arrive(core)
        #expect(core.state.workspaces.space(of: WindowID(4)) == "1")
        #expect(core.state.workspaces.lastFocused == WindowID(4))
        #expect(log.paid)
        #expect(core.jump.owed == nil)
    }

    @Test("Jump on a minimized window with no rule ends focused here")
    func jumpNoRuleFocuses() {
        let core = makeCore()
        core.jump(to: .window(WindowID(4)))
        arrive(core)
        #expect(core.state.workspaces.space(of: WindowID(4)) == "1")
        #expect(core.state.workspaces.lastFocused == WindowID(4))
        #expect(log.paid)
    }

    /// A Jump never moves a window: landing in its rule's Space,
    /// it is the launch follow's to carry the user there.
    @Test("a Jump that lands elsewhere is not moved here")
    func jumpElsewhereStandsDown() {
        let core = makeCore()
        core.state.appRules[bundle] = "2"
        core.jump(to: .window(WindowID(4)))
        arrive(core)
        #expect(core.state.workspaces.space(of: WindowID(4)) == "2")
        expectStoodDown(core)
    }

    @Test("a Space switch before the arrival stands the focus down")
    func switchStandsDown() {
        let core = makeCore()
        #expect(core.moveHere(.window(WindowID(4))))
        core.state.workspaces.activate("2")
        core.state.workspaces.focus(WindowID(2), in: "2")
        arrive(core)
        #expect(core.state.workspaces.activeSpace == "2")
        expectStoodDown(core)
    }

    @Test("an arrival past the bound stands the focus down")
    func boundStandsDown() {
        let core = makeCore()
        #expect(core.moveHere(.window(WindowID(4))))
        core.wallClock = {
            self.start.addingTimeInterval(FollowFocusIntent.drainWindow)
        }
        arrive(core)
        expectStoodDown(core)
    }

    @Test("a press since the move stands the focus down")
    func pressStandsDown() {
        let core = makeCore()
        #expect(core.moveHere(.window(WindowID(4))))
        core.wallClock = { self.start.addingTimeInterval(2) }
        core.launchFollow.pressAge = { 1 }
        arrive(core)
        expectStoodDown(core)
    }

    /// The control: the press that made the move is older.
    @Test("the press that made the move does not stand it down")
    func ownPressPays() {
        let core = makeCore()
        #expect(core.moveHere(.window(WindowID(4))))
        core.wallClock = { self.start.addingTimeInterval(2) }
        core.launchFollow.pressAge = { 3 }
        arrive(core)
        #expect(log.paid)
    }

    @Test("a commanded focus since the move stands the focus down")
    func commandedStandsDown() {
        let core = makeCore()
        #expect(core.moveHere(.window(WindowID(4))))
        core.eventLoop.lastCommandedFocus = .now
        arrive(core)
        expectStoodDown(core)
    }

    @Test("the debt follows a native-tab re-key")
    func rekeyFollows() {
        let core = makeCore()
        #expect(core.moveHere(.window(WindowID(4))))
        core.handle(.windowRekeyed(WindowID(4), WindowID(9)))
        #expect(core.jump.owed?.window == WindowID(9))
    }

    @Test("an empty WindowServer reading keeps every record")
    func emptyReadingAbstains() {
        #expect(JumpState.known([:]) == nil)
        #expect(JumpState.known([WindowID(3): 1]) == [WindowID(3)])
    }
}
