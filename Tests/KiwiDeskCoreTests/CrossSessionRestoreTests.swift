import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private typealias F = BootRestoreFixture

/// The cross-session restore (#1385 rulings 2026-10-09), driven
/// through the boot tail as `finishBoot` runs it: only a file a
/// logout's freeze wrote, refused by the id gates, is matched to
/// the reopened windows — by app, then title, then rank, at boot,
/// at each arrival and at the title pass — once. An in-place
/// restart's own file and a plain Quit's are never matched.
@Suite("Cross-session restore (#1385)", .serialized)
@MainActor
struct CrossSessionRestoreTests: CrossSessionFixture {
    @Test(
        "A freeze's file places the reopened windows by app",
        .enabled(if: NSScreen.main != nil)
    )
    func bootPlacesByApp() throws {
        let core = try #require(
            boot([window(10, "com.a", "A"), window(11, "com.b", "")])
        )
        leave(
            previous([(F.hidden, "com.a", "A"), (F.shown, "com.b", "B")]),
            in: core
        )
        arrange(core)
        #expect(space(core, 10) == F.hidden)
        #expect(space(core, 11) == F.shown)
        #expect(!core.state.crossSession.isOpen)
    }

    /// The old id 10 was another app's window: the live window 10
    /// is never filed by that record.
    @Test(
        "An old id equal to a live one never files it",
        .enabled(if: NSScreen.main != nil)
    )
    func oldIDNamesNothing() throws {
        let core = try #require(
            boot([window(10, "com.b", "B"), window(11, "com.a", "A")])
        )
        leave(previous([(F.hidden, "com.a", "A")], first: 10), in: core)
        arrange(core)
        #expect(space(core, 10) == F.shown)
        #expect(space(core, 11) == F.hidden)
    }

    /// The in-place path: this session's own file is replayed by
    /// id while a freeze's file sits beside it, and the match is
    /// never armed — its unpairable record would hold it open.
    @Test(
        "A same-session file is replayed by id, never matched",
        .enabled(if: NSScreen.main != nil)
    )
    func sameSessionIsNeverMatched() throws {
        let core = try #require(boot([window(10, "com.a", "A")]))
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
        let refused = previous([
            (F.hidden, "com.a", "A"), (F.hidden, "com.z", "Z"),
        ])
        // The autosave makes the directory the stop writes into.
        leave(refused, in: core)
        core.crash.captureInPlaceState = { own }
        core.crash.shutdownCleanly(inPlace: true)
        leave(refused, in: core)
        arrange(core)
        #expect(space(core, 10) == F.shown)
        #expect(!core.state.crossSession.isOpen)
    }

    /// A plain Quit lets go (#1385 ruling): its file, unmarked,
    /// never crosses a boot.
    @Test(
        "A plain Quit's file starts the next boot fresh",
        .enabled(if: NSScreen.main != nil)
    )
    func plainQuitStartsFresh() throws {
        let core = try #require(boot([window(10, "com.a", "A")]))
        leave(previous([(F.hidden, "com.a", "A")], frozen: false), in: core)
        arrange(core)
        #expect(space(core, 10) == F.shown)
        #expect(!core.state.crossSession.isOpen)
    }

    /// Used once: the first launch consumes the freeze's file, and
    /// a second launch in the same boot finds only its own.
    @Test(
        "A second launch in the same boot matches nothing",
        .enabled(if: NSScreen.main != nil)
    )
    func secondLaunchMatchesNothing() throws {
        let core = try #require(boot([window(10, "com.a", "A")]))
        leave(previous([(F.hidden, "com.a", "A")]), in: core)
        arrange(core)
        #expect(space(core, 10) == F.hidden)
        // The next launch reads the same directory: nothing is left.
        _ = core.crash.takeBootSnapshot()
        #expect(core.crash.takeCrossSessionCandidate() == nil)
    }

    /// The scheduled passes, through the deferred seam: the title
    /// pass pairs by title and re-files quietly, the close ends the
    /// match. Neither reads the wall clock, which a step moves.
    @Test(
        "The scheduled title pass and close run on their own clock",
        .enabled(if: NSScreen.main != nil)
    )
    func scheduledPassesRun() async throws {
        let core = try #require(
            boot([
                window(20, "com.ide", "Preview"),
                window(21, "com.ide", "IDE"),
            ])
        )
        var moves = 0
        _ = core.bus.addSink { event, _ in
            if event == .windowMovedToSpace { moves += 1 }
        }
        leave(
            previous([
                (F.shown, "com.ide", "IDE"),
                (F.hidden, "com.ide", "Preview"),
                (F.hidden, "com.z", "Z"),
            ]),
            in: core
        )
        core.deferred.sleep = { _ in }
        arrange(core)
        #expect(space(core, 20) == F.shown)
        core.wallClock = { .distantPast }
        await core.deferred.task(for: .crossSessionSettle)?.value
        #expect(space(core, 20) == F.hidden)
        #expect(space(core, 21) == F.shown)
        #expect(moves == 0)
        await core.deferred.task(for: .crossSessionClose)?.value
        #expect(!core.state.crossSession.isOpen)
    }

    /// The title pass never undoes a user's filing, and leaves the
    /// window the user is in.
    @Test(
        "The title pass leaves a user-filed and the focused window",
        .enabled(if: NSScreen.main != nil)
    )
    func titlePassRespectsTheUser() throws {
        let core = try #require(
            boot([
                window(20, "com.ide", "Preview"),
                window(21, "com.ide", "IDE"),
                window(22, "com.ide", "Notes"),
                window(23, "com.ide", "Draft"),
            ])
        )
        leave(
            previous([
                (F.shown, "com.ide", "IDE"),
                (F.hidden, "com.ide", "Preview"),
                (F.hidden, "com.ide", "Notes"),
                (F.hidden, "com.ide", "Draft"),
            ]),
            in: core
        )
        arrange(core)
        core.moveWindow(WindowID(21), to: F.hidden, follow: false)
        // A drag's drop files through its own seam, not the verb's.
        core.insertDropped(WindowID(23), onto: WindowID(22), into: F.shown)
        core.state.workspaces.focus(WindowID(22), in: F.shown)
        core.crossSessionSettlePass()
        #expect(space(core, 20) == F.hidden)
        #expect(space(core, 21) == F.hidden)
        #expect(space(core, 22) == F.shown)
        #expect(space(core, 23) == F.shown)
    }

    @Test(
        "A late arrival is placed with its frame until the close",
        .enabled(if: NSScreen.main != nil),
        arguments: [false, true]
    )
    func lateArrivalUntilTheClose(closed: Bool) throws {
        let core = try #require(boot([]))
        leave(previous([(F.hidden, "app.zen", "Zen Browser")]), in: core)
        arrange(core)
        if closed { core.closeCrossSessionMatch() }
        core.handle(.windowCreated(window(30, "app.zen", "Zen Browser")))
        #expect(space(core, 30) == (closed ? F.shown : F.hidden))
        if !closed {
            let seeded = core.tiler.stashOriginal(WindowID(30))
            #expect(seeded == Self.recorded)
        }
    }

    /// A Load inside the open window: the records name the old
    /// arrangement's Spaces, so neither late phase files anything.
    @Test(
        "Another arrangement going live closes the match",
        .enabled(if: NSScreen.main != nil)
    )
    func arrangementChangeClosesTheMatch() throws {
        let core = try #require(
            boot([
                window(20, "com.ide", "Preview"),
                window(21, "com.ide", "IDE"),
            ])
        )
        leave(
            previous([
                (F.shown, "com.ide", "IDE"),
                (F.hidden, "com.ide", "Preview"),
                (F.hidden, "app.zen", "Zen Browser"),
            ]),
            in: core
        )
        arrange(core)
        let other = core.buildProfile(name: "Other", modes: nil)
        core.profiles.becameLive(other, fits: true)
        core.handle(.windowCreated(window(30, "app.zen", "Zen Browser")))
        core.crossSessionSettlePass()
        #expect(space(core, 30) == F.shown)
        #expect(space(core, 20) == F.shown)
        #expect(!core.state.crossSession.isOpen)
    }

    @Test(
        "A stop closes the match",
        .enabled(if: NSScreen.main != nil)
    )
    func stopClosesTheMatch() throws {
        let core = try #require(boot([]))
        leave(previous([(F.hidden, "app.zen", "Zen Browser")]), in: core)
        arrange(core)
        #expect(core.state.crossSession.isOpen)
        core.stop()
        #expect(!core.state.crossSession.isOpen)
    }

    /// Both id gates hand a freeze's refusal over — the boot's and
    /// the login session's — and an admitted file never is.
    @Test(
        "Only a freeze's file the id gates refused is matched",
        .enabled(if: NSScreen.main != nil)
    )
    func onlyRefusedFilesAreCandidates() throws {
        let core = try #require(boot([]))
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

    /// The live capture writes the keys the match reads.
    @Test(
        "Every capture records each window's app and title",
        .enabled(if: NSScreen.main != nil)
    )
    func captureRecordsTheKeys() throws {
        var parked = window(11, "com.b", "Beta")
        parked.isFloating = true
        let core = try #require(boot([window(10, "com.a", "Alpha"), parked]))
        core.state.workspaces.add(WindowID(11), to: F.hidden)
        _ = F.settle(core)
        // The parked float's record is `sessionSnapshot`'s own
        // rewrite (`FloatRecovery`), which must keep the keys too.
        #expect(core.tiler.stashOriginal(WindowID(11)) != nil)
        for snapshot in [
            core.state.snapshot(), core.sessionSnapshot(),
            core.sessionSnapshot(inPlace: true),
        ] {
            let keys = Dictionary(
                uniqueKeysWithValues: snapshot.windows.map {
                    ($0.id, "\($0.app ?? "-")|\($0.title ?? "-")")
                }
            )
            #expect(keys == [10: "com.a|Alpha", 11: "com.b|Beta"])
        }
    }
}
