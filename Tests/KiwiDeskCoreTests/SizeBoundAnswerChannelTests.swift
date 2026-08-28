import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The #677 ANSWER channels, split from `RetileBoundSkipTests`
/// at the file ceiling: the settle probe (a refused size emits
/// no event, so the answer is read back), the move/resize echo
/// observations, the immediate residue placement a confirmation
/// triggers, and the forget gate's late-echo exemption. The
/// skip semantics stay next door.
@Suite("Size-bound answer channels (#677)", .serialized)
@MainActor
struct SizeBoundAnswerChannelTests {
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
    /// `applied` — a skipped window simply never appears there.
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

    /// Runs the two probe retiles that teach the engine the
    /// app's refusal, leaving the window's state frame at the
    /// refused answer. Returns (target, refused frame).
    private func learnBound(
        _ core: KiwiCore,
        applied: Applied
    ) throws -> (target: CGRect, refused: CGRect) {
        let target = try #require(
            core.tiler.calculatedFrames(state: core.state)[w]
        )
        // The refusal must exceed the skip tolerance to matter.
        let refused = CGRect(
            origin: target.origin,
            size: CGSize(width: 715, height: target.height)
        )
        for _ in 0..<2 {
            applied.frames = [:]
            core.retile()
            #expect(applied.frames[w] != nil)
            // The app's echo: position taken, width refused.
            core.state.apply(.windowResized(w, refused))
        }
        return (target, refused)
    }

    @Test("An untrusted baseline still needs the ladder")
    func untrustedBaselineNeedsTheLadder() throws {
        // The ask was issued while an echo could still be in
        // flight: the pre-ask frame is not a settled reading,
        // so one observation may only seed — trusting it would
        // confirm false bounds from exactly the stale frames
        // the echo grace exists to exclude.
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
        // Echo-pending at ISSUE time: the gate refuses, so the
        // recorded ask carries no baseline.
        core.tiler.echoGraceOverride = { _ in true }
        core.retile()
        core.handle(.windowResized(w, refused))
        #expect(core.tiler.sizeBound(for: w) == nil)
    }

    @Test("The settle probe answers a silent refusal")
    func settleProbeAnswersSilentRefusal() throws {
        // The production hole (device QA, 2026-08-18): a
        // refused size emits NO event — macOS only reports a
        // size that changed, and a monocle probe does not even
        // move the window — so waiting for echoes starved the
        // ladder. The settle probe reads the answer back
        // directly; its first observation re-asks once on its
        // own, so ONE visit completes the whole ladder.
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

        core.retile()
        // Probe after the first settle: seeds the candidate
        // and re-asks by itself…
        applied.frames = [:]
        core.runSizeBoundProbe(w)
        #expect(core.tiler.sizeBound(for: w) == nil)
        // …the re-ask is the probe's own doing — without it a
        // quiet screen would never produce the second probe.
        #expect(applied.frames[w] != nil)
        // …so the second probe confirms and places, with no
        // user interaction in between.
        applied.frames = [:]
        core.runSizeBoundProbe(w)
        #expect(core.tiler.sizeBound(for: w) != nil)
        let placed = try #require(applied.frames[w])
        #expect(placed.width == 715)
        #expect(abs(placed.midX - target.midX) < 0.01)
    }
    @Test("A move echo carries the answer")
    func moveEchoCarriesTheAnswer() throws {
        // A refused width still moves: the probe's position
        // sets echo as windowMoved, whose frame carries the
        // full size — the one event channel a silent refusal
        // does produce (in scrolling, where slots pan).
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        core.drag.isMousePressed = { false }
        core.tiler.echoGraceOverride = { _ in true }
        let target = try #require(
            core.tiler.calculatedFrames(state: core.state)[w]
        )
        let refused = CGRect(
            origin: target.origin,
            size: CGSize(width: 715, height: target.height)
        )
        core.retile()
        core.handle(.windowMoved(w, refused))
        // The move echo still CARRIES the answer — it seeds the
        // candidate, which is what this test is named for. What
        // it may not do since #1083 is complete the ladder on
        // its own: two raw echoes can be one stale frame read
        // twice, so belief waits for the read that outlasted
        // the grace.
        #expect(core.tiler.sizeBound(for: w) == nil)
        #expect(core.tiler.candidateSizeBound(for: w) != nil)
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
    @Test("A confirmation places the residue in its own turn")
    func confirmPlacesResidueImmediately() throws {
        // The device-QA finding (2026-08-18): learning waited
        // on the NEXT retile, so the re-pack/centering arrived
        // only after "many visits". The confirmation EDGE
        // retiles right then, whichever channel carries it —
        // monocle centers at the confirming observation, not at
        // some later event.
        //
        // Repointed from the echo channel to the settle probe
        // by #1083 (a raw echo no longer promotes). What is
        // unique to this test is the tail: the placement's own
        // echo must not read as a new edge and re-issue. The
        // confirm-and-place half it shares with
        // `settleProbeAnswersSilentRefusal`.
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        // The severed applier never stamps, so inject the
        // "this is our echo" verdict.
        core.tiler.echoGraceOverride = { _ in true }
        let target = try #require(
            core.tiler.calculatedFrames(state: core.state)[w]
        )
        let refused = CGRect(
            origin: target.origin,
            size: CGSize(width: 715, height: target.height)
        )
        // Probe 1: ask, then the app's echo seeds the candidate.
        core.retile()
        core.handle(.windowResized(w, refused))
        #expect(core.tiler.sizeBound(for: w) == nil)
        // The confirming observation is the settled read since
        // #1083 — the immediacy this test exists for is
        // unchanged, and it is what the assertions below hold:
        // the confirmation edge places the residue in its OWN
        // turn rather than waiting for a later event.
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
        #expect(placed.width == 715)
        #expect(abs(placed.midX - target.midX) < 0.01)
        // The placement's own echo (the app performing the
        // centered ask) is no new edge — nothing re-issues.
        applied.frames = [:]
        core.handle(.windowResized(w, placed))
        #expect(applied.frames[w] == nil)
    }
    @Test("A late echo of the answer does not wipe the ledger")
    func lateEchoDoesNotForget() throws {
        // Past the applier's grace (or delayed by the #618 read
        // queue) an echo classifies as non-recent — but its
        // size is one the ledger predicted, so wiping on it
        // would erase the learning it is evidence for (the
        // monocle-never-centers half of the device-QA finding).
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        let (_, refused) = try learnBound(
            core,
            applied: applied
        )
        core.retile()
        #expect(core.tiler.sizeBound(for: w) != nil)

        // A late-delivered echo of the learned answer.
        core.handle(.windowResized(w, refused))
        #expect(core.tiler.sizeBound(for: w) != nil)
    }
    @Test("An un-echoed ask is not observed")
    func staleEchoDoesNotConfirm() throws {
        // The echo-grace gate (review, 2026-08-18): while the
        // last set's echo may still be in flight, the state
        // frame is the stale pre-ask value — a DETERMINISTIC
        // repeated "answer" that two rapid retiles would
        // otherwise confirm as a false bound.
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        core.tiler.echoGraceOverride = { _ in true }
        _ = try learnBound(core, applied: applied)
        applied.frames = [:]
        core.retile()
        // Gated: nothing was learned, so the target re-issues.
        #expect(core.tiler.sizeBound(for: w) == nil)
        #expect(applied.frames[w] != nil)

        // With echoes settled the ladder resumes — the gate
        // discriminates lag, it does not disable learning. The
        // state frame still holds the refusal, so two quiet
        // retiles observe and confirm it.
        core.tiler.echoGraceOverride = { _ in false }
        core.retile()
        core.retile()
        #expect(core.tiler.sizeBound(for: w) != nil)
    }
    @Test("A genuine resize stales the ledger via the event flow")
    func genuineResizeForgets() throws {
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        let (_, refused) = try learnBound(
            core,
            applied: applied
        )
        // Confirmation lands at the NEXT retile's observation
        // (the same pass that first skips).
        core.retile()
        #expect(core.tiler.sizeBound(for: w) != nil)

        // A non-echo resize (the applier is severed here, so
        // nothing is "recently set"): the user or the app
        // itself changed the size — System Settings switching
        // panes — and the ledger must not outlive it.
        core.handle(
            .windowResized(
                w,
                CGRect(
                    origin: refused.origin,
                    size: CGSize(width: 830, height: 700)
                )
            )
        )
        #expect(core.tiler.sizeBound(for: w) == nil)

        applied.frames = [:]
        core.retile()
        // Probing resumes: the target is issued again.
        #expect(applied.frames[w] != nil)
    }
}
