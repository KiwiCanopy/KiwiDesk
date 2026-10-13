import Foundation

@testable import KiwiDeskCore

/// The menu-bar reveal suites' shared fixture (#1532, #2224).
@MainActor
enum MenuBarRevealFixture {
    /// The return's log phrase, asserted POSITIVELY on a return
    /// and NEGATIVELY on the silent let-outs — one constant, so
    /// a reword of the production line reds the positive half
    /// instead of leaving the negative one vacuously green.
    static let returnLogNeedle = "menu-bar reveal activation"

    /// Windows 1 (OUR pid — the anchor) and 2 (a foreign regular
    /// app), window 1 focused, the pointer read pinned IN the
    /// strip: the reveal's shape.
    static func makeCore(inStrip: Bool = true) -> KiwiCore {
        let core = makeTestCore()
        let own = pid_t(ProcessInfo.processInfo.processIdentifier)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: own,
                    appName: "KiwiDesk"
                )
            )
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(2),
                    pid: 99,
                    appName: "Other"
                )
            )
        )
        core.state.workspaces.focus(WindowID(1), in: SpaceID(1))
        core.mouse.pointerInMenuBarStrip = { inStrip }
        return core
    }

    static func focused(_ core: KiwiCore) -> WindowID? {
        core.state.workspaces[SpaceID(1)]?.focused
    }

    static func log(_ core: KiwiCore) -> Lines {
        let lines = Lines()
        core.onLog = { lines.all.append($0) }
        return lines
    }

    final class Lines {
        var all: [String] = []
        func contain(_ text: String) -> Bool {
            all.contains { $0.contains(text) }
        }
    }
}
