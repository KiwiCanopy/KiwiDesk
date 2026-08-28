import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The BASELINE arm of the #677 ladder, split from
/// `SizeBoundAnswerChannelTests` at the file ceiling: a window
/// already settled at its refused size before the ask has
/// answered once already, so one further observation completes
/// the ladder instead of a second dance.
///
/// The pair here IS the settled/raw verdict (#1083) — the two
/// tests share a fixture and differ only in the channel that
/// answers — so keep them in one file: separating them is how
/// the shortcut gets re-widened to the echo with only the
/// permissive half staying green.
@Suite("Size-bound baseline arm (#677, #1083)", .serialized)
@MainActor
struct SizeBoundBaselineTests {
    private let w = WindowID(1)

    /// Captured frame sink — a class so the capture in the
    /// engine's `apply` closure and the suite's reads never
    /// overlap in an exclusivity-checked `inout` (which traps).
    @MainActor
    private final class Applied {
        var frames: [WindowID: CGRect] = [:]
    }

    /// A core with a captured frame pipeline: `animate` is
    /// disabled, so every issued frame lands synchronously in
    /// `applied`.
    private func makeCore(applied: Applied) -> KiwiCore {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1000, height: 800)
        }
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { id, frame, _ in
            applied.frames[id] = frame
        }
        core.state.workspaces.setMode(SpaceID(1), .monocle)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: w, pid: 1, appName: "App")
            )
        )
        return core
    }

    @Test("A quiet issue confirms from a single probe")
    func quietIssueConfirmsFromOneProbe() throws {
        // The latency ask (device QA, 2026-08-18): a window
        // that already HELD a settled size before the ask, and
        // still holds exactly it after the whole animation, has
        // answered twice — pre-ask baseline plus one probe — so
        // the residue places ~one probe grace after the dance,
        // not a full second cycle later.
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        let target = try #require(
            core.tiler.calculatedFrames(state: core.state)[w]
        )
        let refused = CGRect(
            origin: target.origin,
            size: CGSize(width: 715, height: target.height)
        )
        // The window sits settled at its refused size BEFORE
        // the engine ever asks.
        core.state.apply(.windowResized(w, refused))
        core.retile()
        // The answer arrives on the SETTLED channel (#1083):
        // the baseline still shortens the ladder to a single
        // observation — one probe rather than the two
        // `settleProbeAnswersSilentRefusal` needs — but the
        // read that takes it must be the one that waited out
        // the grace.
        core.eventLoop.frameReads.reader = { _ in refused }
        core.eventLoop.frameReads.deliver = { work in
            MainActor.assumeIsolated { work() }
        }
        core.eventLoop.frameReads.dispatchOverride = {
            _,
            work in
            work()
        }
        core.eventLoop.elements[1] = [
            w: AXUIElementCreateSystemWide()
        ]
        applied.frames = [:]
        core.runSizeBoundProbe(w)
        #expect(core.tiler.sizeBound(for: w) != nil)
        let placed = try #require(applied.frames[w])
        #expect(abs(placed.midX - target.midX) < 0.01)
    }

    @Test("A trusted baseline confirms on the first settled read")
    func trustedBaselineConfirmsInOneObservation() {
        // The POSITIVE half of the baseline arm, at the learner
        // rather than through the engine (guard-prover, #1083):
        // driven end-to-end, deleting the whole arm leaves every
        // test green, because the probe's own re-ask retile
        // supplies a second settled observation by another
        // route and the ladder completes anyway. The #677
        // latency win the arm exists for could therefore be
        // removed silently. Here nothing else can answer.
        var learner = SizeBoundLearner()
        let w = WindowID(1)
        let refused = CGSize(width: 715, height: 800)
        // The window sat SETTLED at the refused size before the
        // ask: one prior observation already in hand.
        learner.recordAsk(
            w,
            size: CGSize(width: 980, height: 800),
            settledFrom: refused
        )
        // Hoisted: a mutating call cannot sit inside #expect.
        let confirmed = learner.observe(
            w,
            currentSize: refused,
            settledRead: true
        )
        #expect(confirmed)
        // The ENTRY is believed after one settled read. Not
        // `minWidth`, which is the corroborated accessor and
        // still wants two distinct asks (#933) — the arm buys
        // the entry a cycle earlier, never the corroboration.
        let entries = learner.bound(for: w)?.width ?? []
        #expect(entries.count == 1)
        #expect(entries.first?.answered == 715)
    }

    @Test("Without a baseline the ladder still needs two reads")
    func noBaselineStillNeedsTheLadder() {
        // The arm's boundary, so the test above cannot pass by
        // the learner promoting on ANY single settled read: the
        // identical sequence with no `settledFrom` seeds only.
        var learner = SizeBoundLearner()
        let w = WindowID(1)
        let refused = CGSize(width: 715, height: 800)
        learner.recordAsk(w, size: CGSize(width: 980, height: 800))
        let confirmed = learner.observe(
            w,
            currentSize: refused,
            settledRead: true
        )
        #expect(!confirmed)
        #expect(learner.bound(for: w) == nil)
    }

    @Test("Two raw echoes never confirm between them")
    func repeatedEchoNeverConfirms() throws {
        // The ladder's own half of the settled-read rule
        // (#1083), and the arm the device capture caught: two
        // raw echoes 72 ms apart satisfied "the same answer
        // twice" at load average 8.7, minting a bound at
        // 1231x1011 — the drawn slot geometry — for two
        // different windows within 44 ms of each other. No app
        // redraws in 72 ms; that is ONE stale frame counted as
        // two observations.
        //
        // The baseline arm cannot cover this: here the ask is
        // answered off the baseline, so the ladder runs
        // properly and the question is only whether a RAW
        // repeat may cast the confirming vote.
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        let target = try #require(
            core.tiler.calculatedFrames(state: core.state)[w]
        )
        let refused = CGRect(
            origin: target.origin,
            size: CGSize(width: 715, height: target.height)
        )
        core.tiler.echoGraceOverride = { _ in true }
        // Two asks, each answered by a raw echo carrying the
        // same refusal — the shape that used to confirm.
        for _ in 0..<2 {
            core.retile()
            core.handle(.windowResized(w, refused))
        }
        #expect(core.tiler.sizeBound(for: w) == nil)
        #expect(core.tiler.candidateSizeBound(for: w) != nil)
        // …and the settled read that follows DOES confirm, so
        // the test pins the discrimination rather than mere
        // silence: a learner that never promotes would pass the
        // assertions above and fail this one.
        core.eventLoop.frameReads.reader = { _ in refused }
        core.eventLoop.frameReads.deliver = { work in
            MainActor.assumeIsolated { work() }
        }
        core.eventLoop.frameReads.dispatchOverride = {
            _,
            work in
            work()
        }
        core.eventLoop.elements[1] = [
            w: AXUIElementCreateSystemWide()
        ]
        core.runSizeBoundProbe(w)
        #expect(core.tiler.sizeBound(for: w) != nil)
    }

    @Test("An echo at the baseline never confirms alone")
    func echoAtBaselineNeverConfirms() throws {
        // #1083, device capture 2026-08-28: on the echo channel
        // a reading equal to the pre-ask baseline is ambiguous —
        // "the app refused" and "the app has not redrawn yet"
        // are the same frame — and under load (measured at load
        // average 9.7) the second is ordinary for any app, the
        // fast ones included. Promoting on it recorded our own
        // latency as the app's limit: one false bound per press,
        // each at exactly the pre-press width, after which the
        // next press refused against it and cued a size-limit
        // pill naming a limit the window was nowhere near.
        //
        // Same fixture as `quietIssueConfirmsFromOneProbe`
        // above, differing ONLY in the channel that answers —
        // so the pair is the settled/raw verdict itself, and
        // reverting the `settledRead` term reds this one.
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        let target = try #require(
            core.tiler.calculatedFrames(state: core.state)[w]
        )
        let refused = CGRect(
            origin: target.origin,
            size: CGSize(width: 715, height: target.height)
        )
        core.state.apply(.windowResized(w, refused))
        core.retile()
        core.tiler.echoGraceOverride = { _ in true }
        applied.frames = [:]
        core.handle(.windowResized(w, refused))
        // Seeded, never believed: the ladder still runs, so a
        // window that genuinely refuses is learned on the next
        // trusted observation rather than never.
        #expect(core.tiler.sizeBound(for: w) == nil)
        #expect(core.tiler.candidateSizeBound(for: w) != nil)
    }
}
