import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private typealias F = BootRestoreFixture

/// The cross-session restore (#1385 ruling 2026-10-09), driven
/// through the boot tail as `finishBoot` runs it: a file the id
/// gates refuse is matched to the reopened windows by app, then
/// title, then rank — at boot, at each arrival and once titles
/// settle — and an in-place restart's own file is never matched.
/// The core's wall clock is the match's; boot time is pinned.
@Suite("Cross-session restore (#1385)", .serialized)
@MainActor
struct CrossSessionRestoreTests {
    /// When the snapshot was written; the boot is one second on.
    private static let before = Date(timeIntervalSince1970: 9000)
    private static let frame = CGRect(x: 80, y: 90, width: 600, height: 400)

    private final class Clock {
        var now = Date(timeIntervalSince1970: 50_000)
        func advance(_ seconds: TimeInterval) {
            now = now.addingTimeInterval(seconds)
        }
    }

    private func window(
        _ id: UInt32,
        _ app: String,
        _ title: String
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: pid_t(100 + id),
            appName: app,
            appBundleID: app,
            title: title,
            frame: Self.frame
        )
    }

    /// The previous boot's desk: `rows` per Space, old ids 500+.
    private func previous(
        _ rows: [(space: SpaceID, app: String, title: String)],
        at: Date = before
    ) -> StateSnapshot {
        var records: [StateSnapshot.WindowRecord] = []
        var spaces: [SpaceID: [WindowID]] = [:]
        for (index, row) in rows.enumerated() {
            let id = WindowID(UInt32(500 + index))
            records.append(
                .init(
                    id: id,
                    frame: Self.frame,
                    app: row.app,
                    title: row.title
                )
            )
            spaces[row.space, default: []].append(id)
        }
        return StateSnapshot(
            windows: records,
            spaces: [F.shown, F.hidden].map {
                .init(space: Space(id: $0, windows: spaces[$0] ?? []))
            },
            activeSpace: F.shown.raw,
            capturedAt: at
        )
    }

    /// A core whose boot came after `before`, with `scanned`
    /// tracked in the shown Space, and the clock wired.
    private func boot(
        _ scanned: [ManagedWindow],
        clock: Clock
    ) -> KiwiCore? {
        guard let core = F.makeCore() else { return nil }
        core.wallClock = { clock.now }
        core.crash.bootTime = { Self.before.addingTimeInterval(1) }
        core.defersEventRetiles = true
        for window in scanned {
            core.handle(.windowCreated(window))
        }
        core.defersEventRetiles = false
        return core
    }

    /// Writes `snapshot` as the autosave the boot finds.
    private func leave(_ snapshot: StateSnapshot, in core: KiwiCore) {
        core.crash.captureState = { snapshot }
        core.crash.autosave()
    }

    private func space(_ core: KiwiCore, _ id: UInt32) -> SpaceID? {
        core.state.workspaces.space(of: WindowID(id))
    }

    @Test(
        "A reboot's arrangement places the reopened windows by app",
        .enabled(if: NSScreen.main != nil)
    )
    func bootPlacesByApp() throws {
        let clock = Clock()
        let core = try #require(
            boot(
                [window(10, "com.a", "A"), window(11, "com.b", "")],
                clock: clock
            )
        )
        leave(
            previous([(F.hidden, "com.a", "A"), (F.shown, "com.b", "B")]),
            in: core
        )
        core.arrangeBootDesk(session: core.crash.takeBootSnapshot())
        #expect(space(core, 10) == F.hidden)
        #expect(space(core, 11) == F.shown)
        #expect(core.crash.crossSession.pending.isEmpty)
    }

    /// The in-place path: this session's own file is replayed by
    /// id while a refused one is on disk beside it, never matched.
    @Test(
        "A same-session file is replayed by id, never matched",
        .enabled(if: NSScreen.main != nil)
    )
    func sameSessionIsNeverMatched() throws {
        let clock = Clock()
        let core = try #require(
            boot([window(10, "com.a", "A")], clock: clock)
        )
        let own = StateSnapshot(
            windows: [
                .init(
                    id: WindowID(10),
                    frame: Self.frame,
                    session: .init(
                        floating: nil,
                        sticky: .none,
                        stickyReach: nil
                    )
                )
            ],
            spaces: [
                .init(space: Space(id: F.shown, windows: [WindowID(10)])),
                .init(space: Space(id: F.hidden)),
            ],
            activeSpace: F.shown.raw
        )
        let refused = previous([(F.hidden, "com.a", "A")])
        // The autosave makes the directory the stop writes into.
        leave(refused, in: core)
        core.crash.captureInPlaceState = { own }
        core.crash.shutdownCleanly(inPlace: true)
        leave(refused, in: core)
        core.arrangeBootDesk(session: core.crash.takeBootSnapshot())
        #expect(space(core, 10) == F.shown)
        #expect(core.crash.crossSession.pending.isEmpty)
    }

    /// Two records of one app pair by title, and only once titles
    /// settle; the pass moves the window that was scanned elsewhere.
    @Test(
        "The settle pass pairs by title, never before the settle",
        .enabled(if: NSScreen.main != nil)
    )
    func settlePassPairsByTitle() throws {
        let clock = Clock()
        let core = try #require(
            boot(
                [
                    window(20, "com.ide", "Preview"),
                    window(21, "com.ide", "IDE"),
                ],
                clock: clock
            )
        )
        leave(
            previous([
                (F.shown, "com.ide", "IDE"), (F.hidden, "com.ide", "Preview"),
            ]),
            in: core
        )
        core.arrangeBootDesk(session: core.crash.takeBootSnapshot())
        #expect(space(core, 20) == F.shown)
        clock.advance(CrossSessionMatch.titleSettle - 1)
        core.crossSessionSettlePass()
        #expect(space(core, 20) == F.shown)
        clock.advance(1)
        core.crossSessionSettlePass()
        #expect(space(core, 20) == F.hidden)
        #expect(space(core, 21) == F.shown)
    }

    @Test(
        "A late arrival inside the bound is placed; past it, not",
        .enabled(if: NSScreen.main != nil),
        arguments: [
            (CrossSessionMatch.bound, true),
            (CrossSessionMatch.bound + 1, false),
        ]
    )
    func lateArrivalWithinTheBound(
        after: TimeInterval,
        placed: Bool
    ) throws {
        let clock = Clock()
        let core = try #require(boot([], clock: clock))
        leave(previous([(F.hidden, "app.zen", "Zen Browser")]), in: core)
        core.arrangeBootDesk(session: core.crash.takeBootSnapshot())
        clock.advance(after)
        core.handle(.windowCreated(window(30, "app.zen", "Zen Browser")))
        #expect(space(core, 30) == (placed ? F.hidden : F.shown))
    }

    /// Both id gates hand their refusal over — the boot's and the
    /// login session's — and an admitted file is never handed.
    @Test(
        "Only a file the id gates refused is matched",
        .enabled(if: NSScreen.main != nil)
    )
    func onlyRefusedFilesAreCandidates() throws {
        let clock = Clock()
        let core = try #require(boot([], clock: clock))
        let crash = core.crash
        leave(previous([(F.hidden, "com.a", "A")]), in: core)
        _ = crash.takeBootSnapshot()
        #expect(crash.takeCrossSessionCandidate() != nil)
        leave(previous([(F.hidden, "com.a", "A")], at: Date()), in: core)
        crash.loginSession = { 2 }
        _ = crash.takeBootSnapshot()
        #expect(crash.takeCrossSessionCandidate() != nil)
        crash.loginSession = { 1 }
        leave(previous([(F.hidden, "com.a", "A")], at: Date()), in: core)
        let admitted = crash.takeBootSnapshot()
        #expect(admitted != nil)
        #expect(crash.takeCrossSessionCandidate() == nil)
    }
}
