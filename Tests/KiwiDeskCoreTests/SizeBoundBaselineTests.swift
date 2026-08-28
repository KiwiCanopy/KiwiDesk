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
