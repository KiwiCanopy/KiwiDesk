import Foundation
import Testing

@testable import KiwiDeskCore

/// #673: `minimizeOrder` records which windows are parked, in
/// order and with the app that owned them — captured at the
/// minimize, because the same fold erases the window snapshot
/// carrying the owner a few lines later.
///
/// These pin the record itself: its ordering, its scoping to one
/// app, and every route by which an entry is dropped. What the
/// record is FOR — the restore decision — is
/// `OpenOrFocusRestoreTests`, through the seams that stand in for
/// AX.
@Suite("Minimize order (#673)")
struct MinimizeOrderTests {

    private func window(
        _ raw: UInt32,
        pid: pid_t = 1,
        bundleID: String? = "com.test.a"
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(raw),
            pid: pid,
            appName: "App",
            appBundleID: bundleID,
            title: "W\(raw)"
        )
    }

    private func minimize(
        _ state: inout StateCoordinator,
        _ raw: UInt32
    ) {
        state.apply(
            .windowDestroyed(WindowID(raw), wasMinimized: true)
        )
    }

    @Test("The most recently minimized window of the app wins")
    func lastMinimizedIsNewest() {
        var state = StateCoordinator()
        state.apply(.windowCreated(window(1)))
        state.apply(.windowCreated(window(2)))
        minimize(&state, 1)
        minimize(&state, 2)
        #expect(
            state.lastMinimized(bundleID: "com.test.a")
                == WindowID(2)
        )
    }

    /// Order is by minimize time, not by id or by creation:
    /// re-minimizing an older window makes it the newest.
    @Test("Re-minimizing a window moves it to the front")
    func reMinimizeReorders() {
        var state = StateCoordinator()
        state.apply(.windowCreated(window(1)))
        state.apply(.windowCreated(window(2)))
        minimize(&state, 1)
        minimize(&state, 2)
        state.apply(.windowCreated(window(1)))
        minimize(&state, 1)
        #expect(
            state.lastMinimized(bundleID: "com.test.a")
                == WindowID(1)
        )
        #expect(state.minimizeOrder.count == 2)
    }

    @Test("Each app answers with its own window")
    func perAppRecords() {
        var state = StateCoordinator()
        state.apply(.windowCreated(window(1)))
        state.apply(
            .windowCreated(
                window(2, pid: 2, bundleID: "com.test.b")
            )
        )
        minimize(&state, 1)
        minimize(&state, 2)
        #expect(
            state.lastMinimized(bundleID: "com.test.a")
                == WindowID(1)
        )
        #expect(
            state.lastMinimized(bundleID: "com.test.b")
                == WindowID(2)
        )
        #expect(state.lastMinimized(bundleID: "com.test.c") == nil)
    }

    /// The bundle id is matched lowercased, as the command
    /// normalizes it before asking.
    @Test("Matching is case-insensitive on the bundle id")
    func bundleIDMatchIsLowercased() {
        var state = StateCoordinator()
        state.apply(
            .windowCreated(window(1, bundleID: "COM.Test.A"))
        )
        minimize(&state, 1)
        #expect(
            state.lastMinimized(bundleID: "com.test.a")
                == WindowID(1)
        )
    }

    @Test("A deminiaturize clears the window's record")
    func restoreClearsRecord() {
        var state = StateCoordinator()
        state.apply(.windowCreated(window(1)))
        state.apply(.windowCreated(window(2)))
        minimize(&state, 1)
        minimize(&state, 2)
        state.apply(.windowCreated(window(2)))
        #expect(
            state.lastMinimized(bundleID: "com.test.a")
                == WindowID(1)
        )
    }

    /// A window that closes normally was never minimized, so it
    /// files nothing — only the minimize branch records.
    @Test("A plain close files no minimize record")
    func plainCloseFilesNothing() {
        var state = StateCoordinator()
        state.apply(.windowCreated(window(1)))
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        #expect(state.minimizeOrder.isEmpty)
    }

    @Test("Quitting the app drops its records")
    func terminateClearsRecords() {
        var state = StateCoordinator()
        state.apply(.windowCreated(window(1)))
        state.apply(
            .windowCreated(
                window(2, pid: 2, bundleID: "com.test.b")
            )
        )
        minimize(&state, 1)
        minimize(&state, 2)
        state.apply(.appTerminated(pid: 1))
        #expect(state.lastMinimized(bundleID: "com.test.a") == nil)
        #expect(
            state.lastMinimized(bundleID: "com.test.b")
                == WindowID(2)
        )
    }

    /// A native-tab re-key swaps the id in place here like in
    /// every other id-keyed container (#308).
    /// `WindowRekeyParityTests` reaches this container through
    /// its `String(describing:)` scan but not through its
    /// reflection count pin (a struct element hides the key), so
    /// this is the second net rather than the only one.
    @Test("A re-key moves the minimize record's id")
    func rekeyMovesTheRecord() {
        var state = StateCoordinator()
        state.apply(.windowCreated(window(1)))
        minimize(&state, 1)
        state.rekey(WindowID(1), to: WindowID(9))
        #expect(
            state.lastMinimized(bundleID: "com.test.a")
                == WindowID(9)
        )
        #expect(state.minimizeOrder.count == 1)
    }

    /// The one route to a live `windows[id]` that does NOT pass
    /// through the create fold's prune: `WindowManager.rekey`.
    /// A window minimized and then closed leaves a record; a
    /// later re-key onto that recycled id must not double it,
    /// which is what `rememberMinimized`'s own `removeAll`
    /// covers and nothing else does.
    @Test("A re-key onto a stale record does not double it")
    func rekeyOntoStaleRecordDoesNotDouble() {
        var state = StateCoordinator()
        state.apply(.windowCreated(window(1)))
        minimize(&state, 1)
        #expect(state.minimizeOrder.count == 1)
        // Window 1 is gone; its record is stale. A native tab
        // switch now re-keys a live window onto that id.
        state.apply(.windowCreated(window(2)))
        state.apply(.windowRekeyed(WindowID(2), WindowID(1)))
        minimize(&state, 1)
        #expect(state.minimizeOrder.count == 1)
        #expect(
            state.lastMinimized(bundleID: "com.test.a")
                == WindowID(1)
        )
    }

    /// A window with no bundle id (an unbundled process) records
    /// but can never be selected by bundle id — the AX fallback
    /// covers it.
    @Test("An unbundled window is never selected by bundle id")
    func unbundledWindowIsUnreachable() {
        var state = StateCoordinator()
        state.apply(.windowCreated(window(1, bundleID: nil)))
        minimize(&state, 1)
        #expect(state.minimizeOrder.count == 1)
        #expect(state.lastMinimized(bundleID: "com.test.a") == nil)
    }
}
