import Foundation
import Testing

@testable import KiwiDeskCore

/// Issues #482/#483: a `move_to_space` WITHOUT follow must never
/// act like a follow. When the OS drops the origin-refocus raise,
/// the moved window keeps key focus and its app re-reports it —
/// the move-intent latch drops that re-report instead of letting
/// the focus-follow teleport the user, and the move settle
/// re-raises the origin's focus once when the drop is provable.
@Suite("No-follow move focus latch (#482/#483)", .serialized)
@MainActor
struct MoveFocusLatchTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-move-latch-\(UUID().uuidString)"
                )
        )
    }

    private func addWindow(
        _ core: KiwiCore,
        _ raw: UInt32,
        pid: pid_t
    ) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(raw),
                    pid: pid,
                    appName: "App\(pid)"
                )
            )
        )
    }

    /// One shared generous hang-guard (#344): the poll exits the
    /// moment its condition holds, so a passing run never waits
    /// this out — it only bounds a genuine hang.
    private let latchHangGuardMS = 30_000

    private func pollUntil(
        _ condition: () -> Bool
    ) async {
        var waited = 0
        while !condition(), waited < latchHangGuardMS {
            try? await Task.sleep(for: .milliseconds(20))
            waited += 20
        }
    }

    @Test("Latch ages out; fresh stamps suppress")
    func latchAging() {
        let latch = MoveIntentLatch()
        let now = Date()
        latch.stamp(WindowID(1), at: now)
        #expect(latch.isLatched(WindowID(1), at: now))
        #expect(!latch.isLatched(WindowID(2), at: now))
        let later = now.addingTimeInterval(
            MoveIntentLatch.window + 0.1
        )
        #expect(!latch.isLatched(WindowID(1), at: later))
    }

    @Test("No-follow move latches; follow move does not")
    func noFollowMoveStampsLatch() {
        let core = makeCore()
        addWindow(core, 10, pid: 5)
        addWindow(core, 20, pid: 6)
        core.moveWindow(
            WindowID(20),
            to: SpaceID(2),
            follow: false
        )
        #expect(core.moveLatch.isLatched(WindowID(20)))
        // The follow verb is the user CHOOSING to go — its own
        // switch runs, nothing to latch.
        core.execute("focus_space", args: [.string("1")])
        core.moveWindow(
            WindowID(10),
            to: SpaceID(3),
            follow: true
        )
        #expect(!core.moveLatch.isLatched(WindowID(10)))
    }

    /// An emptied origin takes the yield branch (#446); the moved
    /// window held focus and its app can re-report — same latch.
    @Test("Yield branch latches too")
    func yieldBranchStampsLatch() {
        let core = makeCore()
        addWindow(core, 10, pid: 5)
        core.moveWindow(
            WindowID(10),
            to: SpaceID(2),
            follow: false
        )
        #expect(core.moveLatch.isLatched(WindowID(10)))
    }

    /// The teleport itself (#482/#483 symptom 1): the moved
    /// window's focus re-report must not even schedule a follow.
    @Test("Focus re-report of a just-moved window never follows")
    func reReportAfterMoveIsDropped() {
        let core = makeCore()
        addWindow(core, 10, pid: 5)
        addWindow(core, 20, pid: 6)
        core.moveWindow(
            WindowID(20),
            to: SpaceID(2),
            follow: false
        )
        #expect(core.deferred.task(for: .focusFollow) == nil)
        core.handle(.windowFocused(WindowID(20)))
        #expect(core.deferred.task(for: .focusFollow) == nil)
        #expect(
            core.state.workspaces.activeSpace == SpaceID(1)
        )
    }

    /// The guardrail: a genuine focus of the moved window AFTER
    /// the latch ages out follows normally (#22 intact).
    @Test("An aged-out latch lets the follow schedule again")
    func expiredLatchFollowsNormally() {
        let core = makeCore()
        addWindow(core, 10, pid: 5)
        addWindow(core, 20, pid: 6)
        core.moveWindow(
            WindowID(20),
            to: SpaceID(2),
            follow: false
        )
        // Backdate the stamp past the window — the deliberate
        // click arriving later.
        core.moveLatch.stamp(
            WindowID(20),
            at: Date().addingTimeInterval(
                -(MoveIntentLatch.window + 0.1)
            )
        )
        core.handle(.windowFocused(WindowID(20)))
        #expect(core.deferred.task(for: .focusFollow) != nil)
    }

    @Test("Move settle armed only when the move held focus")
    func settleArmedOnlyWhenMovedHeldFocus() {
        let core = makeCore()
        addWindow(core, 10, pid: 5)
        addWindow(core, 20, pid: 6)
        addWindow(core, 30, pid: 7)
        // Window 10 did NOT hold focus (30 is `lastFocused`):
        // no hazard, no settle.
        core.moveWindow(
            WindowID(10),
            to: SpaceID(2),
            follow: false
        )
        #expect(core.deferred.task(for: .moveSettle) == nil)
        // Window 30 held focus and window 20 remains to refocus:
        // settle armed.
        core.moveWindow(
            WindowID(30),
            to: SpaceID(3),
            follow: false
        )
        #expect(core.deferred.task(for: .moveSettle) != nil)
    }

    /// End to end (#463 pattern): the moved window's app provably
    /// kept frontmost through the settle — re-raise the origin's
    /// focus once, and say so.
    @Test("Move settle re-raises when the refocus was dropped")
    func settleReassertsDroppedRefocus() async {
        let core = makeCore()
        var logs: [String] = []
        core.onLog = { logs.append($0) }
        // The moved window's app (pid 6) never loses frontmost.
        core.frontmostPIDProvider = { 6 }
        addWindow(core, 10, pid: 5)
        addWindow(core, 20, pid: 6)
        core.moveWindow(
            WindowID(20),
            to: SpaceID(2),
            follow: false
        )
        await pollUntil {
            logs.contains { $0.contains("re-raising") }
        }
        #expect(
            logs.contains {
                $0.contains("move settle")
                    && $0.contains("re-raising window 10")
            }
        )
    }

    /// The latch is id-keyed bookkeeping, so a native-tab rekey
    /// (#308) inside the 1 s window must carry the stamp to the
    /// fresh id — the moved window still holds OS key focus in
    /// this exact hazard, so its re-report arrives under the NEW
    /// id (mirrors the `selfRaiseStamps` transfer).
    @Test("A rekey inside the window keeps the moved id latched")
    func rekeyCarriesLatch() {
        let core = makeCore()
        addWindow(core, 10, pid: 5)
        addWindow(core, 20, pid: 6)
        core.moveWindow(
            WindowID(20),
            to: SpaceID(2),
            follow: false
        )
        core.handle(
            .windowRekeyed(WindowID(20), WindowID(21))
        )
        #expect(!core.moveLatch.isLatched(WindowID(20)))
        #expect(core.moveLatch.isLatched(WindowID(21)))
    }

    /// The settle is origin-scoped: if the user switched spaces
    /// before it fired, hands off (mirrors `scheduleSpaceSettle`).
    @Test("Move settle inert once the origin is left")
    func settleInertAfterSpaceChange() async {
        let core = makeCore()
        var logs: [String] = []
        core.onLog = { logs.append($0) }
        core.frontmostPIDProvider = { 6 }
        addWindow(core, 10, pid: 5)
        addWindow(core, 20, pid: 6)
        core.scheduleMoveSettle(
            origin: SpaceID(1),
            priorFrontmost: 6
        )
        core.execute("focus_space", args: [.string("4")])
        _ = await core.deferred.task(for: .moveSettle)?.value
        #expect(!logs.contains { $0.contains("re-raising") })
    }
}
