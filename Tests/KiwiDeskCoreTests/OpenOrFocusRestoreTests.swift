import Foundation
import Testing

@testable import KiwiDeskCore

/// #673: Open or Focus for an app whose windows are all
/// minimized used to do nothing visible — `activate()` does not
/// deminiaturize. It now restores exactly one, the most recently
/// minimized, and only when the app has nothing up.
///
/// Every machine touch of the already-running branch sits behind
/// `openOrFocus` — the app lookup, the window census, the
/// deminiaturize, the activate and the launch — so the two
/// decisions (*whether* to reach into the Dock, and *which*
/// window to bring back) are reachable without a real app, and
/// their ORDER is observable through one shared log.
@MainActor
@Suite("Open or Focus restore (#673)", .serialized)
struct OpenOrFocusRestoreTests {

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-restore-\(UUID().uuidString)"
                )
        )
    }

    /// One log for both writes, so their ORDER is observable and
    /// not just their occurrence.
    private enum Touch: Equatable {
        case deminiaturize(pid_t, WindowID)
        case activate(pid_t)
    }

    private final class Recorder {
        var log: [Touch] = []
        var calls: [(pid_t, WindowID)] {
            log.compactMap {
                if case .deminiaturize(let pid, let id) = $0 {
                    return (pid, id)
                }
                return nil
            }
        }
    }

    /// States the world for a running app at pid 7 and records
    /// every touch. Both branches of `launch` are seamed — the
    /// running one and the LaunchServices fall-through — so a
    /// test can neither activate nor start a real app, whatever
    /// bundle id it names (`tests.md`: a test reaches the machine
    /// only through a seam it injects).
    private func wire(
        _ core: KiwiCore,
        visible: Int,
        minimized: [UInt32]
    ) -> Recorder {
        let recorder = Recorder()
        core.openOrFocus.runningAppPID = { _ in 7 }
        core.openOrFocus.census = { _ in
            KiwiCore.AppWindowCensus(
                visible: visible,
                minimized: minimized.map { WindowID($0) }
            )
        }
        core.openOrFocus.deminiaturize = { pid, id in
            recorder.log.append(.deminiaturize(pid, id))
        }
        core.openOrFocus.activate = { pid in
            recorder.log.append(.activate(pid))
        }
        return recorder
    }

    // MARK: - Whether to reach into the Dock

    @Test("Nothing up: one window comes back")
    func restoresWhenNothingVisible() {
        let core = makeCore()
        let recorder = wire(core, visible: 0, minimized: [1, 2])
        core.restoreOneMinimizedIfNothingVisible(
            pid: 7,
            bundleID: "com.test.a"
        )
        #expect(recorder.calls.count == 1)
        #expect(recorder.calls.first?.0 == 7)
    }

    /// The rule's other half, and the one that matters most: a
    /// minimize is a parking decision, so while ANY window is up
    /// the shortcut leaves the Dock alone. One visible window is
    /// enough — including for an app hidden with ⌘H, whose
    /// windows AX still lists as un-minimized.
    @Test("Anything up: the Dock is left alone")
    func skipsWhenSomethingVisible() {
        let core = makeCore()
        let recorder = wire(core, visible: 1, minimized: [1, 2])
        core.restoreOneMinimizedIfNothingVisible(
            pid: 7,
            bundleID: "com.test.a"
        )
        #expect(recorder.calls.isEmpty)
    }

    @Test("Nothing up and nothing parked: no-op")
    func skipsWhenNothingMinimized() {
        let core = makeCore()
        let recorder = wire(core, visible: 0, minimized: [])
        core.restoreOneMinimizedIfNothingVisible(
            pid: 7,
            bundleID: "com.test.a"
        )
        #expect(recorder.calls.isEmpty)
    }

    /// Exactly one, never the set: the user parked them
    /// individually, and a press that un-parks a session's worth
    /// of windows cannot be undone with one press.
    @Test("Only one window is restored, never all of them")
    func restoresExactlyOne() {
        let core = makeCore()
        let recorder = wire(
            core,
            visible: 0,
            minimized: [1, 2, 3, 4]
        )
        core.restoreOneMinimizedIfNothingVisible(
            pid: 7,
            bundleID: "com.test.a"
        )
        #expect(recorder.calls.count == 1)
    }

    // MARK: - Which window comes back

    @Test("The app's most recently minimized window wins")
    func picksTheRememberedWindow() {
        let core = makeCore()
        for id in UInt32(1)...3 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: 7,
                        appName: "App",
                        appBundleID: "com.test.a"
                    )
                )
            )
            core.state.apply(
                .windowDestroyed(
                    WindowID(id),
                    wasMinimized: true
                )
            )
        }
        let recorder = wire(
            core,
            visible: 0,
            minimized: [1, 2, 3]
        )
        core.restoreOneMinimizedIfNothingVisible(
            pid: 7,
            bundleID: "com.test.a"
        )
        // Window 3 went down last — not window 1, which the
        // kAXWindows fallback would have picked.
        #expect(recorder.calls.first?.1 == WindowID(3))
    }

    /// The cold-start path, and not an edge case: a KiwiDesk
    /// launched over already-minimized windows has no record at
    /// all, so the app's own `kAXWindows` order decides.
    @Test("With no record, the app's first parked window wins")
    func fallsBackToAXOrder() {
        let core = makeCore()
        let recorder = wire(core, visible: 0, minimized: [5, 6])
        core.restoreOneMinimizedIfNothingVisible(
            pid: 7,
            bundleID: "com.test.a"
        )
        #expect(recorder.calls.first?.1 == WindowID(5))
    }

    /// A record can also be stale — a window closed while
    /// minimized fires no event — so the census, not the record,
    /// is the authority on what is still parked.
    @Test("A stale record loses to the live census")
    func staleRecordFallsBack() {
        let core = makeCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(99),
                    pid: 7,
                    appName: "App",
                    appBundleID: "com.test.a"
                )
            )
        )
        core.state.apply(
            .windowDestroyed(WindowID(99), wasMinimized: true)
        )
        #expect(
            core.state.lastMinimized(bundleID: "com.test.a")
                == WindowID(99)
        )
        let recorder = wire(core, visible: 0, minimized: [5, 6])
        core.restoreOneMinimizedIfNothingVisible(
            pid: 7,
            bundleID: "com.test.a"
        )
        #expect(recorder.calls.first?.1 == WindowID(5))
    }

    /// Another app's record must not select this app's window.
    @Test("A record of another app does not select")
    func otherAppRecordIsIgnored() {
        let core = makeCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(6),
                    pid: 8,
                    appName: "Other",
                    appBundleID: "com.test.b"
                )
            )
        )
        core.state.apply(
            .windowDestroyed(WindowID(6), wasMinimized: true)
        )
        let recorder = wire(core, visible: 0, minimized: [5, 6])
        core.restoreOneMinimizedIfNothingVisible(
            pid: 7,
            bundleID: "com.test.a"
        )
        #expect(recorder.calls.first?.1 == WindowID(5))
    }

    // MARK: - The command path

    @Test("pull_or_spawn drives the restore for a running app")
    func commandDrivesTheRestore() {
        let core = makeCore()
        let recorder = wire(core, visible: 0, minimized: [1])
        #expect(
            core.execute(
                "pull_or_spawn",
                args: [.string("com.test.a")]
            ).isSuccess
        )
        #expect(recorder.calls.count == 1)
        #expect(recorder.calls.first?.1 == WindowID(1))
    }

    /// The restore runs BEFORE the activate, so the app comes
    /// forward with a window already on its way up rather than a
    /// beat behind it. Both touches share one log precisely so
    /// this is assertable — recording only that each happened
    /// leaves the claim in the comments unguarded.
    @Test("The restore runs before the app is brought forward")
    func restoreRunsBeforeActivate() {
        let core = makeCore()
        let recorder = wire(core, visible: 0, minimized: [1])
        _ = core.execute(
            "pull_or_spawn",
            args: [.string("com.test.a")]
        )
        #expect(
            recorder.log == [
                .deminiaturize(7, WindowID(1)),
                .activate(7),
            ]
        )
    }

    /// The app still comes forward when there is nothing to
    /// restore — the restore is an addition to that branch, not
    /// a replacement for it.
    @Test("An app with windows up is still brought forward")
    func activatesWithoutRestoring() {
        let core = makeCore()
        let recorder = wire(core, visible: 2, minimized: [1])
        _ = core.execute(
            "pull_or_spawn",
            args: [.string("com.test.a")]
        )
        #expect(recorder.log == [.activate(7)])
    }

    /// An app that is not running takes the LaunchServices path
    /// instead, and must not be reported as restored.
    @Test("A stopped app touches neither seam")
    func stoppedAppTouchesNothing() {
        let core = makeCore()
        let recorder = wire(core, visible: 0, minimized: [1])
        core.openOrFocus.runningAppPID = { _ in nil }
        _ = core.execute(
            "pull_or_spawn",
            args: [.string("com.test.does.not.exist")]
        )
        #expect(recorder.log.isEmpty)
    }
}
