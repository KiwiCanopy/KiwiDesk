import ApplicationServices
import CoreGraphics
import Foundation

/// Applies animation frames to real windows via per-app queues without
/// blocking the clock.
@MainActor
final class FrameApplier {
    var elementProvider: @MainActor (WindowID) -> AXUIElement? =
        { _ in nil }

    private var animatingPid: [WindowID: pid_t] = [:]
    private var pidCounts: [pid_t: Int] = [:]
    private var queues: [pid_t: DispatchQueue] = [:]
    private let pending = PendingFrames()
    private let recent = RecentApplies()
    private let instantTargets = InstantTargets()
    let enhancedUI = EnhancedUIHolds()
    /// Writes the plate slide holds until it lands (#1956).
    let held = HeldWrites()
    /// Whose motion the writes in this turn are (#804); read by the
    /// input-quiescence gate.
    let motion = MotionScope()

    /// Moves one of KiwiDesk's own windows through AppKit, in
    /// this turn; false where no own window answers, and the AX
    /// write goes ahead. A test records it.
    var ownWindowMove: @MainActor (WindowID, CGRect, Bool) -> Bool =
        FrameApplier.moveOwnWindow

    /// The AX writes the queues perform; a test counts them.
    var writer = FrameWriter.live

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
    private static let echoGrace: TimeInterval = 1.0

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

    /// Commanded frame from recent `applyInstant` while echo is in flight
    /// (#881).
    func instantTarget(_ id: WindowID) -> CGRect? {
        instantTargets.frame(id, within: Self.echoGrace, now: clock())
    }

    /// Retires instant target stamp upon arrival of first self-echo.
    func clearInstantTarget(_ id: WindowID) {
        instantTargets.clear(id)
    }

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
        guard let pid = animatingPid.removeValue(forKey: id)
        else { return }
        pidCounts[pid, default: 1] -= 1
        if pidCounts[pid, default: 0] <= 0 {
            pidCounts[pid] = nil
            holdEUI(pid: pid, held: false)
        }
    }

    /// Dispatches frame to target app queue (position-only unless `setSize`).
    func apply(_ id: WindowID, _ frame: CGRect, setSize: Bool) {
        // Ahead of the element guard and the coalescing return,
        // like `applyInstant`'s target stamp: the echo must never
        // precede the stamp (#1254).
        recent.record(id, now: clock())
        issued(id, frame)
        if stageHeld(id, frame, setSize: setSize) { return }
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
                setSize: setSize
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
            if entry.setSize {
                writer.setFrame(entry.frame, entry.element)
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

    /// Applies a frame instantly, with EUI held off around the
    /// set (#881) — one hold for a run of sets queued back to
    /// back, shared with the animation ref-count through
    /// `EnhancedUIHolds` (#1508). Position-only unless `setSize`.
    /// Callers must `animation.cancel(window:)` first (as
    /// `retile` and `stashInactive` do) so a window is never
    /// spring-animated and instant-set at once.
    func applyInstant(
        _ id: WindowID,
        _ frame: CGRect,
        setSize: Bool
    ) {
        // Recorded before the element guard, at enqueue time: the
        // overlay sync wants the commanded frame this same turn
        // (#881); a stamp for a gone window expires unread.
        instantTargets.record(id, frame: frame, now: clock())
        recent.record(id, now: clock())  // as `apply`, #1254
        issued(id, frame)
        if stageHeld(id, frame, setSize: setSize) { return }
        guard let element = elementProvider(id) else { return }
        guard
            let pid = animatingPid[id] ?? Self.pid(of: element)
        else { return }
        // Our own window moves now, inside the caller's turn: the
        // main queue would run it only after that turn (#1956).
        if pid == getpid(), ownWindowMove(id, frame, setSize) {
            recentStamp(id)
            return
        }
        nonisolated(unsafe) let target = element
        let recent = recent
        let clock = clock
        let writer = writer
        let holds = enhancedUI
        let waited = meter.queued()
        holds.noteQueued(
            pid,
            atRest: enhancedUIAtRest(pid),
            instant: true
        )
        queue(for: pid).async {
            waited()
            holds.beginInstant(pid, writer)
            if setSize {
                writer.setFrame(frame, target)
            } else {
                writer.setPosition(frame.origin, target)
            }
            holds.endInstant(pid, writer)
            recent.record(id, now: clock())  // as `apply`, #1254
        }
    }

    /// Stamps a set's return from a queue block (#1254).
    var recentStamp: @Sendable (WindowID) -> Void {
        let recent = recent
        let clock = clock
        return { recent.record($0, now: clock()) }
    }

    func queue(for pid: pid_t) -> DispatchQueue {
        // Own process runs on main queue to prevent AppKit thread traps
        // (#678 Phase 5).
        if pid == getpid() {
            return DispatchQueue.main
        }
        if let existing = queues[pid] {
            return existing
        }
        let queue = DispatchQueue(
            label: "org.kiwidesk.frames.\(pid)",
            qos: .userInteractive
        )
        queues[pid] = queue
        return queue
    }

    /// EUI holds ride the same per-app queue as the frames, so
    /// off → frames → on ordering is guaranteed.
    private func holdEUI(pid: pid_t, held: Bool) {
        let holds = enhancedUI
        let writer = writer
        if held {
            holds.noteQueued(
                pid,
                atRest: enhancedUIAtRest(pid),
                instant: false
            )
        }
        queue(for: pid).async {
            if held {
                holds.acquire(pid, writer)
            } else {
                holds.release(pid, writer)
            }
        }
    }

    /// The event loop stopped owning the app and left its EUI
    /// at `leftOn`; a hold still open restores that.
    func retireApp(_ pid: pid_t, leftOn: Bool) {
        enhancedUI.retire(pid, leftOn: leftOn)
    }

    static func pid(of element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success
        else { return nil }
        return pid
    }
}
