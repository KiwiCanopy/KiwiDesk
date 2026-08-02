import Foundation
import Testing

@testable import KiwiDeskCore

/// #673: Open or Focus restores one window when every window of
/// the app is minimized, and "one" is the most recently
/// minimized. `minimizedWindows` cannot answer that — an
/// unordered `Set<WindowID>` whose entries the same fold strips
/// of their app — so the order and the owner are recorded at the
/// minimize, while the window snapshot is still live.
///
/// The AX half (is anything on screen, which element to write
/// `kAXMinimizedAttribute` on) needs a real app and is not
/// reachable here; what these pin is the choice it acts on.
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
    /// every other id-keyed container (#308). Reflection cannot
    /// discover this one — its element is a struct, not a
    /// `WindowID` — so `WindowRekeyParityTests` does not cover
    /// it and this is the net.
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
