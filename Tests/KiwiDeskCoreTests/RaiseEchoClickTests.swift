import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-echo-click-\(UUID().uuidString)"
        )
    let core = makeTestCore(configDirectory: directory)
    // Pin the display (tests.md / #531): the fall-through path
    // retiles, and its geometry must not be the host's screen.
    core.tiler.visibleBounds = { _ in
        CGRect(x: 0, y: 25, width: 1440, height: 875)
    }
    return core
}

/// Three windows on one space: `intended` focused, the other two
/// overlapping each other (an edge pile's shape) and stamped in
/// the raise-echo ledger, as a z-order restore leaves them.
@MainActor
private func makePile(
    _ core: KiwiCore
) -> (intended: WindowID, top: WindowID, under: WindowID) {
    let frames: [CGRect] = [
        CGRect(x: 0, y: 0, width: 400, height: 300),
        CGRect(x: 500, y: 0, width: 400, height: 300),
        CGRect(x: 450, y: 0, width: 400, height: 300),
    ]
    for id in 1...3 {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(UInt32(id)),
                    pid: pid_t(id),
                    appName: "App\(id)",
                    frame: frames[id - 1]
                )
            )
        )
    }
    let intended = WindowID(1)
    let space = core.state.workspaces.space(of: intended)!
    core.state.workspaces.focus(intended, in: space)
    _ = core.stampZOrderRaise(
        [WindowID(2), WindowID(3)],
        excluding: intended
    )
    return (intended, WindowID(2), WindowID(3))
}

@MainActor
private func focused(_ core: KiwiCore) -> WindowID? {
    core.activeSpace?.focused
}

/// A point inside BOTH pile frames — where containment alone
/// cannot say which window a click reached.
private let overlapPoint = CGPoint(x: 600, y: 100)

/// #687: a genuine click on a window a z-order restore stamped is
/// shaped exactly like the restore's own raise echo, so the
/// revert consumed it — the ring and pan stayed behind while
/// macOS focused the clicked window. A recent click that REACHED
/// the reported window is provenance no echo can forge, so it
/// escapes the revert. "Reached" is resolved at press time
/// (`clickReachedWindow`, its own suite below); this suite pins
/// what the revert does with the resolved fact.
@Suite("Raise-echo revert vs. clicks (#687)", .serialized)
@MainActor
struct RaiseEchoClickTests {
    @Test("A clickless stamped report is reverted")
    func echoWithoutClickReverts() {
        let core = makeCore()
        let (intended, top, _) = makePile(core)
        core.handle(.windowFocused(top))
        #expect(focused(core) == intended)
        // NOT consumed: lazy apps re-report a raised window,
        // and an unstamped duplicate was honored as deliberate
        // focus — the snap-back of #689's device trace. The
        // stamp expires by age instead.
        #expect(core.zOrderRaiseEchoes[top] != nil)
        // The duplicate report inside the window reverts too.
        core.handle(.windowFocused(top))
        #expect(focused(core) == intended)
    }

    /// The veto is age-bounded (#689 device trace): a STALE
    /// self-raise stamp — a no-echo re-assert's leftover —
    /// must not block the ledger revert, or a lazy app's late
    /// re-report threads both nets (the stale stamp vetoes the
    /// ledger; the age bound rightly says it is no self-echo)
    /// and focus snaps back to the pile-mate.
    @Test("A stale self-raise stamp cannot veto the revert")
    func staleSelfRaiseStampDoesNotVeto() {
        let core = makeCore()
        let (intended, top, _) = makePile(core)
        // Stamped, never echoed, and past the echo window —
        // the shape a no-echo raise leaves behind.
        core.selfRaiseStamps[top] = Date(
            timeIntervalSinceNow: -KiwiCore.selfRaiseEchoWindow - 1
        )
        core.handle(.windowFocused(top))
        #expect(focused(core) == intended)
    }

    /// The veto is ORDER, not freshness (#887): a self stamp
    /// older than the z-order stamp is the restore's own echo.
    @Test("A self-raise older than the z-order stamp cannot veto")
    func olderSelfRaiseStampDoesNotVeto() {
        let core = makeCore()
        let (intended, top, _) = makePile(core)
        core.selfRaiseStamps[top] = Date(timeIntervalSinceNow: -0.5)
        core.handle(.windowFocused(top))
        #expect(focused(core) == intended)
    }

    /// The #431 arm the order keeps: a keyboard focus landing
    /// on a window a restore stamped EARLIER is a newer self
    /// stamp, and the revert must not undo it.
    @Test("A self-raise newer than the z-order stamp vetoes")
    func newerSelfRaiseStampVetoes() {
        let core = makeCore()
        let (_, top, _) = makePile(core)
        core.selfRaiseStamps[top] = Date(timeIntervalSinceNow: 0.1)
        core.handle(.windowFocused(top))
        #expect(focused(core) == top)
    }

    @Test("A click that reached the window escapes the revert")
    func clickOnReportedWindowIsHonored() {
        let core = makeCore()
        let (_, top, _) = makePile(core)
        core.lastLeftClick = (Date(), overlapPoint, top)
        core.handle(.windowFocused(top))
        #expect(focused(core) == top)
        // The stamp survives the escape: the raise's real echo
        // may still be in flight, and if focus has moved on by
        // then, that echo must still be reverted.
        #expect(core.zOrderRaiseEchoes[top] != nil)
    }

    /// The reason "reached" is stricter than containment: the
    /// click reached the TOP pile window, and the report under
    /// test is the UNDER window's late echo — whose frame also
    /// contains the click point. Honoring it would pan the row
    /// onto a window the user did not click.
    @Test("A buried pile-mate's echo is still reverted")
    func buriedPileMateEchoReverts() {
        let core = makeCore()
        let (intended, top, under) = makePile(core)
        core.lastLeftClick = (Date(), overlapPoint, top)
        core.handle(.windowFocused(under))
        #expect(focused(core) == intended)
    }

    @Test("A click that reached another window is no provenance")
    func clickOnOtherWindowReverts() {
        let core = makeCore()
        let (intended, top, _) = makePile(core)
        core.lastLeftClick = (
            Date(), CGPoint(x: 100, y: 100), intended
        )
        core.handle(.windowFocused(top))
        #expect(focused(core) == intended)
    }

    @Test("A click older than the echo window is no provenance")
    func staleClickReverts() {
        let core = makeCore()
        let (intended, top, _) = makePile(core)
        core.lastLeftClick = (
            Date().addingTimeInterval(
                -KiwiCore.zOrderRaiseEchoWindow - 0.1
            ),
            overlapPoint,
            top
        )
        core.handle(.windowFocused(top))
        #expect(focused(core) == intended)
    }

    /// A press the stamp could not resolve (unwired provider,
    /// or a click that hit nothing tracked) is no provenance —
    /// the revert must behave exactly as before #687.
    @Test("An unresolved click means no escape")
    func unresolvedClickReverts() {
        let core = makeCore()
        let (intended, top, _) = makePile(core)
        core.lastLeftClick = (Date(), overlapPoint, nil)
        core.handle(.windowFocused(top))
        #expect(focused(core) == intended)
    }
}

/// The press-time resolution feeding the suite above (#687):
/// which managed window a left press reached. Resolved AT PRESS
/// TIME — by echo time a drain may have restacked the pile (a
/// quiet raise of a same-app sibling becomes the app's new key
/// window) and a retile may have moved the frames, so an
/// echo-time read could resolve a stamped sibling and forge the
/// escape (architect review, 2026-08-03).
@Suite("Click-reach resolution (#687)", .serialized)
@MainActor
struct ClickReachResolutionTests {
    @Test("The frontmost frame containing the point wins")
    func frontmostContainingWins() {
        let core = makeCore()
        let (intended, top, under) = makePile(core)
        core.stackingOrderProvider = {
            [top, under, intended]
        }
        #expect(
            core.clickReachedWindow(at: overlapPoint) == top
        )
        // Stacking decides the overlap tie, so the reversed
        // order resolves the other pile-mate.
        core.stackingOrderProvider = {
            [under, top, intended]
        }
        #expect(
            core.clickReachedWindow(at: overlapPoint) == under
        )
    }

    /// The accepted narrowness, pinned: stacking entries the
    /// state does not track (an ignored window, an overlay) are
    /// skipped rather than resolved — a click on one resolves
    /// to the managed window beneath, which fails toward
    /// honoring a focus report, never toward eating one.
    @Test("Untracked stacking entries are skipped")
    func untrackedEntriesAreSkipped() {
        let core = makeCore()
        let (intended, top, under) = makePile(core)
        core.stackingOrderProvider = {
            [WindowID(999), top, under, intended]
        }
        #expect(
            core.clickReachedWindow(at: overlapPoint) == top
        )
    }

    @Test("A point outside every frame resolves nothing")
    func missResolvesNil() {
        let core = makeCore()
        let (intended, top, under) = makePile(core)
        core.stackingOrderProvider = {
            [top, under, intended]
        }
        #expect(
            core.clickReachedWindow(
                at: CGPoint(x: 1200, y: 800)
            ) == nil
        )
    }

    @Test("An unwired provider resolves nothing")
    func unwiredProviderResolvesNil() {
        let core = makeCore()
        _ = makePile(core)
        #expect(
            core.clickReachedWindow(at: overlapPoint) == nil
        )
    }
}
