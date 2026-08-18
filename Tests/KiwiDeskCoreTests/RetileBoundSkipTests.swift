import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The #677 re-issue loop, ended: a target the app has twice
/// refused reads as "already there", so a retile stops
/// restarting an animation the window can never perform. The
/// ladder itself is `SizeBoundLearnerTests`; this suite proves
/// `TilingEngine.retile` consults it — and only where it may
/// (never forced, never for a moved slot, never after the
/// event flow staled the ledger).
@Suite("Retile bound skip (#677)", .serialized)
@MainActor
struct RetileBoundSkipTests {
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

    @Test("The third retile stops re-issuing a refused target")
    func thirdRetileSkips() throws {
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        let (target, _) = try learnBound(
            core,
            applied: applied
        )
        #expect(target.width > 717)

        applied.frames = [:]
        core.retile()
        #expect(applied.frames[w] == nil)
        #expect(
            core.tiler.sizeBound(for: w)?.width?.answered
                == 715
        )
    }

    @Test("Force still re-issues past a learned bound")
    func forceStillIssues() throws {
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        _ = try learnBound(core, applied: applied)

        applied.frames = [:]
        core.retile(force: true)
        // An explicit apply keeps its contract (#42 tolerance
        // rule): everything re-issues, bound or no bound.
        #expect(applied.frames[w] != nil)
    }

    @Test("A moved slot still issues")
    func movedSlotStillIssues() throws {
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        _ = try learnBound(core, applied: applied)

        // The display narrows, so the monocle slot moves and
        // resizes: the skip must not swallow real motion.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 100, y: 0, width: 800, height: 800)
        }
        applied.frames = [:]
        core.retile()
        let reissued = try #require(applied.frames[w])
        let moved = try #require(
            core.tiler.calculatedFrames(state: core.state)[w]
        )
        #expect(reissued == moved)
    }

    @Test("A slot translated at the same size still issues")
    func translatedSlotStillIssues() throws {
        // The position half of the skip (guard-prover,
        // 2026-08-18): a display-origin shift moves the slot
        // WITHOUT changing its size, so the size axes are all
        // explained by the bound and only the position check
        // forces the re-issue.
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        _ = try learnBound(core, applied: applied)
        // Confirm (and skip) at the next retile, so the
        // translation below runs against a believed bound.
        core.retile()
        #expect(core.tiler.sizeBound(for: w) != nil)

        core.tiler.visibleBounds = { _ in
            CGRect(x: 300, y: 0, width: 1000, height: 800)
        }
        applied.frames = [:]
        core.retile()
        let reissued = try #require(applied.frames[w])
        let moved = try #require(
            core.tiler.calculatedFrames(state: core.state)[w]
        )
        #expect(reissued == moved)
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
