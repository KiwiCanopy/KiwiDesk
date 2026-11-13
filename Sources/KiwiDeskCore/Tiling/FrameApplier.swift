import ApplicationServices
import CoreGraphics
import Foundation

/// Applies animation frames to real windows via per-app queues without
/// blocking the clock.
@MainActor
final class FrameApplier {
    var elementProvider: @MainActor (WindowID) -> AXUIElement? =
        { _ in nil }

    var animatingPid: [WindowID: pid_t] = [:]
    private var pidCounts: [pid_t: Int] = [:]
    /// Where a floating resize's window was at its press (#2981):
    /// lasts a spring or one instant write.
    var sizeLedRuns: [WindowID: SizeLedRun] = [:]
    let fixedSizeDoor = FixedSizeDoor()
    /// Per-app frame queues, made by `queue(for:)`.
    var queues: [pid_t: DispatchQueue] = [:]
    private let pending = PendingFrames()
    /// The grab's waiting instant sets, one per window (#3266).
    let latestInstants = PendingFrames()
    let recent = RecentApplies()
    let instantTargets = InstantTargets()
    let enhancedUI = EnhancedUIHolds()
    /// Writes the plate slide holds until it lands (#1956).
    let held = HeldWrites()
    /// Whose motion the writes in this turn are (#804): the open
    /// scope, and the one full reading (`KiwiCore.motionCause`,
    /// wired at bootstrap) the input-quiescence gate will take.
    let motion = MotionScope()
    var cause: @MainActor () -> MotionCause = { .ambient }

    /// Moves one of KiwiDesk's own windows through AppKit in this
    /// turn; false where none answers, so the AX write goes ahead.
    var ownWindowMove: @MainActor (WindowID, CGRect, Bool) -> Bool =
        FrameApplier.moveOwnWindow

    /// The AX writes the queues perform; a test counts them.
    var writer = FrameWriter.live

    /// Every screen's whole AX frame, for the edge band and `sizeLead`.
    var screenFrames: @MainActor () -> [CGRect] = { [] }
    /// "Displays have separate Spaces", for the edge band (#2966).
    var separateSpaces: @MainActor () -> Bool = { false }

    /// Whether the app's EUI is on at rest — the event loop's
    /// warmed baseline, wired at bootstrap. Off by default: an
    /// unwired applier never toggles the flag.
    var enhancedUIAtRest: @MainActor (pid_t) -> Bool = { _ in false }

    /// Every frame issued to a window, at both entry points and
    /// ahead of the element guard — the one sink every layout,
    /// stash, restore and `setFrame` frame reaches, so a test can
    /// see what a pass moved (#930). A no-op in production.
    var issued: @MainActor (WindowID, CGRect) -> Void = { _, _ in }

    /// Counts coalesced frames and per-app queue waits (#1508);
    /// set by `TilingEngine.meter`, which owns the choice.
    var meter = WorkMeter.shared

    /// Grace period for ignoring self-inflicted AX frame echoes.
    static let echoGrace: TimeInterval = 1.0

    /// The clock the echo grace is measured on. Live by default;
    /// `makeTestCore` freezes it, since a starved runner can let
    /// the grace pass between a retile's stamp and the read that
    /// asks for it (#1456, tests.md ▸ age-bounded ledgers).
    var clock: @Sendable () -> TimeInterval = {
        ProcessInfo.processInfo.systemUptime
    }

    /// True if a frame-set for the window was ISSUED or performed
    /// within the echo grace — tells our own AX echoes apart from
    /// user drags. Without it a settled animation's echo reads as
    /// a drag end, and in stack layouts (all slots overlap) that
    /// fake drop swaps windows and retriggers itself forever.
    /// Stamped at enqueue AND after the set: an app posts its
    /// notification while performing the set, so the echo can
    /// precede a post-set stamp (#1254, `FrameApplierStampTests`);
    /// the post-set stamp keeps the grace running from the set's
    /// return for a queue that runs late (`SizeBoundGateNeedleTests`).
    func didRecentlySetFrame(_ id: WindowID) -> Bool {
        recent.isRecent(id, within: Self.echoGrace, now: clock())
    }

    /// Seconds since a frame-set for the window was last stamped,
    /// on the applier's clock; nil when none is on record.
    func secondsSinceSet(_ id: WindowID) -> TimeInterval? {
        recent.age(id, now: clock())
    }

    /// Commanded frame from recent `applyInstant` while echo is in flight
    /// (#881).
    func instantTarget(_ id: WindowID) -> CGRect? {
        instantTargets.frame(id, within: Self.echoGrace, now: clock())
    }

    /// Retires instant target stamp upon arrival of first self-echo.
    func clearInstantTarget(_ id: WindowID) {
        instantTargets.clear(id)
    }

    /// Called once per sweep in which instant writes' commanded
    /// leads lapsed with no echo (#2882); inert unwired, wired once
    /// at bootstrap.
    var instantLeadLapsed: @MainActor () -> Void = {}

    /// Runs a lapse sweep after its delay, on the main actor; a
    /// test fires it by hand. Apart from `scheduleResend`, so a
    /// suite stepping resends never receives a sweep.
    var scheduleLapse:
        @MainActor (TimeInterval, @escaping @MainActor () -> Void)
            -> Void = { delay, work in
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    MainActor.assumeIsolated(work)
                }
            }

    /// How far past the grace a lapse sweep runs.
    static let lapseMargin: TimeInterval = 0.05

    /// Whether a lapse sweep is scheduled: one for every lead owed.
    var lapseSweepPending = false

    /// Marks window animating and disables app EnhancedUserInterface.
    func beginAnimating(_ id: WindowID) {
        guard animatingPid[id] == nil,
            let element = elementProvider(id),
            let pid = Self.pid(of: element)
        else { return }
        animatingPid[id] = pid
        pidCounts[pid, default: 0] += 1
        if pidCounts[pid] == 1 {
            holdEUI(pid: pid, held: true)
        }
    }

    /// Ends window animation and restores EnhancedUserInterface if last.
    func endAnimating(_ id: WindowID) {
        sizeLedRuns[id] = nil
        guard let pid = animatingPid.removeValue(forKey: id)
        else { return }
        pidCounts[pid, default: 1] -= 1
        if pidCounts[pid, default: 0] <= 0 {
            pidCounts[pid] = nil
            holdEUI(pid: pid, held: false)
        }
    }

    /// The lead for this write, spent unless a spring carries it.
    func takeLead(_ id: WindowID) -> SizeLedWrite.Lead? {
        guard let run = sizeLedRuns[id] else { return nil }
        if animatingPid[id] == nil { sizeLedRuns[id] = nil }
        return sizeLead(id, run: run)
    }

    /// Dispatches frame to target app queue (position-only unless `setSize`).
    func apply(_ id: WindowID, _ frame: CGRect, setSize: Bool) {
        // Ahead of the element guard and the coalescing return: the
        // echo must never precede the stamp (#1254).
        recent.record(id, now: clock())
        issued(id, frame)
        pendingResends[id] = nil  // a spring supersedes a resend
        _ = latestInstants.take(id)  // and a waiting grab frame
        let band = edgeBand(frame, setSize: setSize)
        let lead = takeLead(id)
        if stageHeld(id, frame, setSize: setSize, band: band, lead: lead) {
            return
        }
        guard let element = elementProvider(id) else { return }
        guard
            let pid = animatingPid[id] ?? Self.pid(of: element)
        else { return }
        nonisolated(unsafe) let target = element
        let alreadyScheduled = pending.put(
            id,
            PendingFrames.Entry(
                element: target,
                frame: frame,
                setSize: setSize,
                band: band,
                lead: lead
            )
        )
        guard !alreadyScheduled else {
            meter.add(\.framesCoalesced)
            return
        }
        let store = pending
        let recent = recent
        let clock = clock
        let writer = writer
        let waited = meter.queued()
        queue(for: pid).async {
            waited()
            guard let entry = store.take(id) else { return }
            if let lead = entry.lead {
                lead.write(entry, writer)
            } else if entry.setSize {
                EdgeBandWrite.write(
                    entry.frame,
                    entry.element,
                    nearEdgeOf: entry.band,
                    writer: writer
                )
            } else {
                writer.setPosition(
                    entry.frame.origin,
                    entry.element
                )
            }
            // Kept beside the enqueue stamp: the grace runs from
            // the set's RETURN for a queue that runs late (#1254).
            recent.record(id, now: clock())
        }
    }

    /// How long a cross-screen set waits before its second write.
    var crossScreenResendDelay: TimeInterval = 0.2

    /// Runs a resend after its delay, on the main actor; a test
    /// fires it by hand.
    var scheduleResend:
        @MainActor (TimeInterval, @escaping @MainActor () -> Void)
            -> Void = { delay, work in
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    MainActor.assumeIsolated(work)
                }
            }

    /// Whether a window's owed resend stands down at fire time —
    /// the engine's drag exemption, wired at its init.
    var resendStandsDown: @MainActor (WindowID) -> Bool = { _ in false }

    /// Each window's set still owed its second write, cleared by
    /// any newer write to that window.
    var pendingResends: [WindowID: CGRect] = [:]
    func forgetResend(_ id: WindowID, unlessSized size: CGSize) {
        if pendingResends[id]?.size != size { pendingResends[id] = nil }
    }

    /// The second write of a set that moved a window onto another
    /// screen: an app easing its frame (EUI on, Zen) clamps the
    /// first one's size to the screen it left (#2187). Stands
    /// down when a newer write — a park, a later pass, a spring —
    /// superseded it, or a spring or a drag holds the window.
    /// The same ask as the first write, so deliberately not an
    /// engine frame: it retires no ask and stamps no placement
    /// (#1694, #1161).
    func resendIfCurrent(
        _ id: WindowID,
        _ frame: CGRect,
        run: SizeLedRun?
    ) {
        guard pendingResends[id] == frame, animatingPid[id] == nil,
            !resendStandsDown(id)
        else { return }
        sizeLedRuns[id] = run
        applyInstant(id, frame, setSize: true)
    }

    /// Stamps a set's return from a queue block (#1254).
    var recentStamp: @Sendable (WindowID) -> Void {
        let recent = recent
        let clock = clock
        return { recent.record($0, now: clock()) }
    }

    static func pid(of element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success
        else { return nil }
        return pid
    }
}
