import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// New Window and Close Window on a window's bar menu (#1518):
/// offered from state alone, acting through `new_window` and
/// `close_window`, and refusing at perform time with a cue where
/// the app answers that it has no such row or button.
@Suite("Bar window action rows", .serialized)
@MainActor
struct BarWindowActionRowsTests {
    private let one = SpaceID("1")
    private let two = SpaceID("2")

    /// Windows 1–3 of "Safari" (pid 41) on Space 1, with 2 and 3
    /// moved to Space 2; each has an AX element of its own, so a
    /// press can be told apart by window; the log captured.
    private func seededCore(log: Log = Log()) -> KiwiCore {
        LocalizationManager.shared.select("en")
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-win-action-\(UUID())")
        )
        let display = DisplayID(7)
        core.state.workspaces.upsertDisplay(
            Display(
                id: display,
                name: "Desk",
                frame: CGRect(x: 0, y: 0, width: 1000, height: 600)
            )
        )
        core.state.workspaces.assign(one, to: display)
        core.state.workspaces.assign(two, to: display)
        core.state.workspaces.activate(one)
        var elements: [WindowID: AXUIElement] = [:]
        for raw in [UInt32(1), 2, 3] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 41,
                        appName: "Safari",
                        appBundleID: "com.apple.safari",
                        title: "Page \(raw)"
                    )
                )
            )
            elements[WindowID(raw)] = AXUIElementCreateApplication(
                pid_t(40 + raw)
            )
        }
        core.eventLoop.elements[41] = elements
        for raw in [2.0, 3.0] {
            core.execute("move_to_space", args: [.string("2"), .number(raw)])
        }
        core.onLog = { log.lines.append($0) }
        return core
    }

    final class Log { var lines: [String] = [] }

    private func row(_ rows: [BarMenuRow], _ title: String) -> BarMenuRow? {
        rows.first { $0.title == title }
    }

    private func perform(_ row: BarMenuRow?) {
        guard case .action(let perform)? = row?.kind else {
            Issue.record("\(row?.title ?? "nil") is not an action")
            return
        }
        perform()
    }

    @Test("New Window activates the app, presses, and owes a follow")
    func newWindowActs() {
        let core = seededCore()
        var activated: [pid_t] = []
        var pressed: [pid_t] = []
        core.openOrFocus.activate = { activated.append($0) }
        core.windowActions.newWindow = { pid, done in
            pressed.append(pid)
            done(true)
        }
        let rows = core.barMenuRows(.appItem([WindowID(1)]))
        #expect(row(rows, "New Window")?.enabled == true)
        perform(row(rows, "New Window"))
        #expect(activated == [41])
        #expect(pressed == [41])
        #expect(core.launchFollow.owed(at: Date()) == "com.apple.safari")
    }

    @Test("New Window with no such row cues a refusal, not a fail")
    func newWindowRefuses() {
        let log = Log()
        let core = seededCore(log: log)
        core.windowActions.newWindow = { _, done in done(false) }
        let reply = core.execute("new_window", args: [.number(1)])
        #expect(reply.isSuccess)
        #expect(log.lines.contains("no enabled New Window item: w1"))
        // Nothing opened, so nothing is owed (#1599).
        #expect(core.launchFollow.owed(at: Date()) == nil)
    }

    /// Another app's debt is not this refusal's to retire.
    @Test("a refused New Window leaves another app's follow owed")
    func refusalKeepsAnotherDebt() {
        let core = seededCore()
        core.windowActions.newWindow = { _, done in
            core.oweLaunchFollow("com.other.app")
            done(false)
        }
        core.execute("new_window", args: [.number(1)])
        #expect(core.launchFollow.owed(at: Date()) == "com.other.app")
    }

    @Test("Close Window presses the named window's own element")
    func closeActs() {
        let core = seededCore()
        var closed: [AXUIElement] = []
        core.windowActions.close = { element, done in
            closed.append(element)
            done(true)
        }
        let rows = core.barMenuRows(.glyph([WindowID(2)]))
        perform(row(rows, "Close Window"))
        let element = core.eventLoop.element(for: WindowID(2))
        #expect(closed.count == 1)
        #expect(closed.first.map { CFEqual($0, element) } == true)
    }

    @Test("a group's Close Window names each window")
    func closeSubmenu() throws {
        let log = Log()
        let core = seededCore(log: log)
        core.windowActions.close = { _, done in done(false) }
        let rows = core.barMenuRows(.glyph([WindowID(2), WindowID(3)]))
        let close = try #require(row(rows, "Close Window"))
        guard case .submenu(let items) = close.kind else {
            Issue.record("Close Window is not a submenu")
            return
        }
        #expect(items.map(\.title) == ["Page 2", "Page 3"])
        perform(items[1])
        #expect(log.lines == ["no enabled close button: w3"])
    }

    @Test("a window with no AX element fails the verb at once")
    func closeWithoutElement() {
        let core = seededCore()
        core.eventLoop.elements[41] = [:]
        #expect(!core.execute("close_window", args: [.number(1)]).isSuccess)
    }

    @Test("both rows are greyed, and both verbs fail, for KiwiDesk")
    func ownProcess() {
        let core = seededCore()
        let own = ProcessInfo.processInfo.processIdentifier
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(9), pid: own, appName: "KiwiDesk")
            )
        )
        let rows = core.barMenuRows(.appItem([WindowID(9)]))
        #expect(row(rows, "New Window")?.enabled == false)
        #expect(row(rows, "Close Window")?.enabled == false)
        for verb in ["new_window", "close_window"] {
            #expect(!core.execute(verb, args: [.number(9)]).isSuccess)
        }
    }

    /// The pill draws on the window it names where it is drawn —
    /// a shown Space, and not parked — and on the focused window
    /// otherwise.
    @Test("a refusal draws on the target when drawn, else the focus")
    func cueTarget() {
        let core = seededCore()
        core.tiler.allScreenBounds = {
            [CGRect(x: 0, y: 0, width: 1000, height: 600)]
        }
        let parked = CGRect(
            x: 1000 - TilingEngine.stashPeekX,
            y: 600 - TilingEngine.stashPeekY,
            width: 400,
            height: 300
        )
        for (raw, frame) in [
            (UInt32(4), CGRect(x: 100, y: 100, width: 400, height: 300)),
            (UInt32(5), parked),
        ] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 41,
                        appName: "Safari",
                        frame: frame,
                        // No layout slot: the frame is the state's.
                        isFloating: true
                    )
                )
            )
        }
        core.state.workspaces.focus(WindowID(1), in: one)
        #expect(core.focusedWindowID == WindowID(1))
        #expect(core.tiler.looksStashed(parked))
        #expect(core.cueWindow(for: WindowID(4)) == WindowID(4))
        #expect(core.cueWindow(for: WindowID(5)) == WindowID(1))
        #expect(core.cueWindow(for: WindowID(2)) == WindowID(1))
    }

    @Test("the pill's sentences name their subject")
    func sentences() {
        LocalizationManager.shared.select("en")
        #expect(
            WindowActionRefusal.noNewWindow(app: "Claude").sentence
                == "Claude has no New Window command"
        )
        #expect(
            WindowActionRefusal.noCloseButton(window: "Preview").sentence
                == "“Preview” has no close button"
        )
    }
}
