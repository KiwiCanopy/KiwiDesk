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

    /// Grace period for ignoring self-inflicted AX frame echoes.
    private static let echoGrace: TimeInterval = 1.0

    /// The clock the echo grace is measured on. Live by default;
    /// `makeTestCore` freezes it, since a starved runner can let
    /// a whole second pass between a retile's stamp and the read
    /// that asks for it (#1456, tests.md ▸ age-bounded ledgers).
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
            setEUI(pid: pid, enabled: false)
        }
    }

    /// Ends window animation and restores EnhancedUserInterface if last.
    func endAnimating(_ id: WindowID) {
        guard let pid = animatingPid.removeValue(forKey: id)
        else { return }
        pidCounts[pid, default: 1] -= 1
        if pidCounts[pid, default: 0] <= 0 {
            pidCounts[pid] = nil
            setEUI(pid: pid, enabled: true)
        }
    }

    /// Dispatches frame to target app queue (position-only unless `setSize`).
    func apply(_ id: WindowID, _ frame: CGRect, setSize: Bool) {
        // Ahead of the element guard and the coalescing return,
        // like `applyInstant`'s target stamp: the echo must never
        // precede the stamp (#1254).
        recent.record(id, now: clock())
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
        guard !alreadyScheduled else { return }
        let store = pending
        let recent = recent
        let clock = clock
        queue(for: pid).async {
            guard let entry = store.take(id) else { return }
            if entry.setSize {
                WindowControl.setFrame(
                    entry.frame,
                    of: entry.element
                )
            } else {
                WindowControl.setPosition(
                    entry.frame.origin,
                    of: entry.element
                )
            }
            // Kept beside the enqueue stamp: the grace runs from
            // the set's RETURN for a queue that runs late (#1254).
            recent.record(id, now: clock())
        }
    }

    /// Applies a frame instantly, dropping EUI around the set
    /// (#881). Deliberately outside the `begin/endAnimating`
    /// ref-count: every EUI toggle and frame-set for a pid rides
    /// the one serial queue, so the live read observes the correct
    /// interleaved state. Callers must `animation.cancel(window:)`
    /// first (as `retile` and `stashInactive` do) so a window is
    /// never spring-animated and instant-set at once.
    func applyInstant(_ id: WindowID, _ frame: CGRect) {
        // Recorded before the element guard, at enqueue time: the
        // overlay sync wants the commanded frame this same turn
        // (#881); a stamp for a gone window expires unread.
        instantTargets.record(id, frame: frame, now: clock())
        recent.record(id, now: clock())  // as `apply`, #1254
        guard let element = elementProvider(id) else { return }
        guard
            let pid = animatingPid[id] ?? Self.pid(of: element)
        else { return }
        nonisolated(unsafe) let target = element
        let recent = recent
        let clock = clock
        queue(for: pid).async {
            let wasEnabled =
                AXHelper.getEnhancedUserInterface(pid: pid)
                == true
            if wasEnabled {
                AXHelper.setEnhancedUserInterface(
                    pid: pid,
                    enabled: false
                )
            }
            WindowControl.setFrame(frame, of: target)
            if wasEnabled {
                AXHelper.setEnhancedUserInterface(
                    pid: pid,
                    enabled: true
                )
            }
            recent.record(id, now: clock())  // as `apply`, #1254
        }
    }

    private func queue(for pid: pid_t) -> DispatchQueue {
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

    /// EUI toggles ride the same per-app queue as the frames, so
    /// off → frames → on ordering is guaranteed.
    private func setEUI(pid: pid_t, enabled: Bool) {
        queue(for: pid).async {
            AXHelper.setEnhancedUserInterface(
                pid: pid,
                enabled: enabled
            )
        }
    }

    private static func pid(of element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success
        else { return nil }
        return pid
    }
}

/// Instant-set target frames awaiting AX echo (#881).
private final class InstantTargets: @unchecked Sendable {
    private typealias Entry = (frame: CGRect, at: TimeInterval)
    private let lock = NSLock()
    private var entries: [WindowID: Entry] = [:]

    func record(_ id: WindowID, frame: CGRect, now: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        entries[id] = (frame, now)
    }

    func frame(
        _ id: WindowID,
        within interval: TimeInterval,
        now: TimeInterval
    ) -> CGRect? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries[id] else { return nil }
        if now - entry.at > interval {
            entries[id] = nil
            return nil
        }
        return entry.frame
    }

    func clear(_ id: WindowID) {
        lock.lock()
        defer { lock.unlock() }
        entries[id] = nil
    }
}

/// Recent frame application timestamps for echo suppression.
private final class RecentApplies: @unchecked Sendable {
    private let lock = NSLock()
    private var stamps: [WindowID: TimeInterval] = [:]

    func record(_ id: WindowID, now: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        stamps[id] = now
    }

    func isRecent(
        _ id: WindowID,
        within interval: TimeInterval,
        now: TimeInterval
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let stamp = stamps[id] else { return false }
        if now - stamp > interval {
            stamps[id] = nil
            return false
        }
        return true
    }
}

/// Pending frames per window shared across threads.
private final class PendingFrames: @unchecked Sendable {
    struct Entry {
        let element: AXUIElement
        var frame: CGRect
        var setSize: Bool
    }

    private let lock = NSLock()
    private var entries: [WindowID: Entry] = [:]

    /// Stores the newest frame; returns true when an apply is
    /// already scheduled. A pending size change survives being
    /// overwritten by a position-only frame.
    func put(_ id: WindowID, _ entry: Entry) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if let existing = entries.removeValue(forKey: id) {
            var merged = entry
            merged.setSize = entry.setSize || existing.setSize
            entries[id] = merged
            return true
        }
        entries[id] = entry
        return false
    }

    func take(_ id: WindowID) -> Entry? {
        lock.lock()
        defer { lock.unlock() }
        return entries.removeValue(forKey: id)
    }
}
