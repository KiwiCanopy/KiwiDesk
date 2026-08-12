import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The wake/unlock path's DIAGNOSTIC half (#835).
///
/// The defect — a lock → lid → unlock cycle rearranging a
/// Scrolling space — is intermittent, and no failing cycle has
/// been captured with logging on. It cannot be fixed on a green
/// suite, and a predicate chosen before the capture is a guess
/// with tests around it. So what ships is the observation, and
/// what this suite pins is that each line the next capture needs
/// is actually emitted: before, the wake path logged on FAILURE
/// alone, which is why an empty log could not tell "restored
/// correctly" from "never restored".
///
/// Two conventions here, each bought by a guard-prover run
/// (2026-08-13):
///
/// - **Assert on the LINE, not on the joined log.** The arm line
///   and the replay line both carry the session clause, so a
///   whole-log `contains` stayed green with the replay line
///   deleted outright. A test named for one line must read that
///   line.
/// - **Await `pendingReplay`, never poll.** The green above was
///   bought at the full 30 s hang guard, which is the same
///   starvation #791 turned out to be.
///
/// The session read is faked throughout (tests.md — a production
/// default that grabs live host state gets an injected fake), so
/// no run here touches `CGSessionCopyCurrentDictionary`.
@Suite("Wake restore diagnostics (#835)")
@MainActor
struct SleepWakeDiagnosticsTests {
    private func sample() -> StateSnapshot {
        StateSnapshot(
            windows: [
                .init(
                    id: WindowID(1),
                    frame: CGRect(x: 1, y: 2, width: 3, height: 4)
                )
            ],
            spaces: [],
            activeSpace: "1"
        )
    }

    @MainActor
    private final class LogBox {
        var lines: [String] = []
    }

    /// The one line containing `needle`. Fails the test when no
    /// line matches, so an assertion about a line's CONTENT can
    /// never pass by that line being absent.
    private func line(
        _ needle: String,
        in log: LogBox
    ) throws -> String {
        try #require(
            log.lines.first { $0.contains(needle) },
            "no logged line contains \"\(needle)\""
        )
    }

    private func makeManager(
        _ log: LogBox,
        locked: Bool? = false
    ) -> SleepWakeManager {
        let manager = SleepWakeManager()
        manager.restoreDelayMS = 0
        manager.onLog = { log.lines.append($0) }
        manager.captureState = { self.sample() }
        manager.displayFingerprints = { ["main"] }
        manager.restoreState = { _ in }
        manager.sessionPresence = {
            SessionPresence(onConsole: true, screenLocked: locked)
        }
        return manager
    }

    /// THE decisive line. On the hypothesized mechanism the wake
    /// leg's replay fires while the screen is still locked and
    /// clears the capture, so the unlock leg — the one that could
    /// have corrected it — lands here and does nothing. It used
    /// to do nothing silently, which is precisely why a captured
    /// log could not confirm or refute the mechanism.
    @Test("a return leg with nothing to replay says so")
    func emptyReturnLegIsAnnounced() {
        let log = LogBox()
        let manager = makeManager(log)
        manager.systemDidReturn(.unlock)
        #expect(
            log.lines == [
                "wake restore: unlock found no held capture — "
                    + "nothing to replay"
            ]
        )
    }

    /// The positive half: a replay that WORKED leaves a line.
    /// Without it an untroubled log is indistinguishable from a
    /// replay that never ran.
    @Test("a replay records what it replayed, and how stale")
    func replayIsRecorded() async throws {
        let log = LogBox()
        let manager = makeManager(log)
        manager.systemWillRest(.sleep)
        manager.systemDidReturn(.wake)
        await manager.pendingReplay?.value
        let replay = try line("replayed", in: log)
        #expect(replay.contains("wake replayed 1 windows"))
        #expect(replay.contains("captured "))
        #expect(replay.contains("s ago"))
    }

    /// The fact the next failing capture turns on. `screenLocked`
    /// is the measurement the issue's proposed predicate
    /// (`kCGSessionOnConsoleKey`) cannot make — see
    /// `SessionPresence` — so the replay line has to carry it.
    @Test("the replay line carries the session's lock state")
    func replayCarriesTheSessionLockState() async throws {
        let log = LogBox()
        let manager = makeManager(log, locked: true)
        manager.systemWillRest(.sleep)
        manager.systemDidReturn(.wake)
        await manager.pendingReplay?.value
        #expect(
            try line("replayed", in: log)
                .contains("screen locked")
        )
    }

    /// The topology skip already logged; it now carries the same
    /// session clause, so a skip and a replay are read the same
    /// way rather than one of them being the informative one.
    @Test("the topology skip carries them too")
    func skipCarriesTheSessionLockState() async throws {
        let log = LogBox()
        let manager = makeManager(log, locked: true)
        var displays = ["main", "side"]
        manager.displayFingerprints = { displays }
        manager.systemWillRest(.lock)
        displays = ["main"]
        manager.systemDidReturn(.unlock)
        await manager.pendingReplay?.value
        #expect(
            try line("wake restore skipped", in: log)
                .contains("screen locked")
        )
    }

    /// A lock → lid cycle rests TWICE before returning once. The
    /// second capture silently discards the first, and the
    /// sequence of events is the thing the log has to make
    /// legible for the mechanism to be arguable at all.
    ///
    /// Asserted as whole lines rather than by `contains`: the
    /// clause must be absent from the FIRST capture as well as
    /// present on the second, and a `contains` on the first line
    /// caught only one of those directions (guard-prover).
    @Test("a second rest names itself and says it replaced")
    func secondRestIsAnnounced() {
        let log = LogBox()
        let manager = makeManager(log)
        manager.systemWillRest(.lock)
        manager.systemWillRest(.sleep)
        #expect(
            log.lines == [
                "wake restore: lock captured 1 windows in 0 spaces",
                "wake restore: sleep captured 1 windows in 0 "
                    + "spaces, replacing a held capture",
            ]
        )
    }

    /// A capture that returned nothing is not the same event as
    /// no capture at all, and the disabled toggle is neither.
    @Test("an empty capture is distinguished from no capture")
    func emptyCaptureIsDistinguished() {
        let log = LogBox()
        let manager = makeManager(log)
        manager.captureState = { nil }
        manager.systemWillRest(.sleep)
        #expect(
            log.lines == [
                "wake restore: sleep captured nothing "
                    + "(capture returned no state)"
            ]
        )
        #expect(!manager.holdsSnapshot)
    }

    @Test("the master toggle stays silent when off")
    func disabledLogsNothing() {
        let log = LogBox()
        let manager = makeManager(log)
        manager.isEnabled = false
        manager.systemWillRest(.sleep)
        manager.systemDidReturn(.wake)
        #expect(log.lines.isEmpty)
    }
}

/// `SessionPresence`'s decoding, driven from dictionaries rather
/// than from the host: `live()` is one statement precisely so
/// this is reachable without a login session, and a CI runner
/// with no console session would otherwise decide the assertions.
///
/// The `nil` case is the one that matters. macOS omits the
/// screen-lock key entirely on an unlocked session (observed
/// 2026-08-13, macOS 26.6.1), so absent must NOT decode to
/// `false` — a diagnostic that reports a fact it did not measure
/// is how the wrong predicate gets picked.
@Suite("SessionPresence decoding (#835)")
struct SessionPresenceTests {
    private let lockedKey = "CGSSessionScreenIsLocked"

    @Test("an absent lock key is unknown, never unlocked")
    func absentLockKeyIsUnknown() {
        let presence = SessionPresence(
            session: [kCGSessionOnConsoleKey: NSNumber(value: 1)]
        )
        #expect(presence.onConsole == true)
        #expect(presence.screenLocked == nil)
        #expect(
            presence.summary
                == "screen lock not reported, on console"
        )
    }

    @Test("a present lock key decodes both ways")
    func presentLockKeyDecodes() {
        let locked = SessionPresence(
            session: [lockedKey: NSNumber(value: 1)]
        )
        #expect(locked.screenLocked == true)
        #expect(locked.summary == "screen locked, console unknown")
        let unlocked = SessionPresence(
            session: [lockedKey: NSNumber(value: 0)]
        )
        #expect(unlocked.screenLocked == false)
        #expect(
            unlocked.summary == "screen unlocked, console unknown"
        )
    }

    /// No dictionary at all — the session read can fail outright,
    /// and it must degrade to "unknown" rather than to a verdict.
    @Test("an unreadable session is unknown on every axis")
    func unreadableSessionIsUnknown() {
        let presence = SessionPresence(session: nil)
        #expect(presence.onConsole == nil)
        #expect(presence.screenLocked == nil)
        #expect(
            presence.summary
                == "screen lock not reported, console unknown"
        )
    }

    /// A non-numeric value is a shape change, not a fact.
    @Test("a non-numeric value is unknown, not true")
    func nonNumericValueIsUnknown() {
        let presence = SessionPresence(
            session: [kCGSessionOnConsoleKey: "yes"]
        )
        #expect(presence.onConsole == nil)
    }
}
