import ApplicationServices
import CoreGraphics
import Foundation

/// Applies animation frames to real windows without ever
/// blocking the animation clock.
///
/// AX frame-setting is synchronous IPC into the target app
/// (1–20 ms per call), so frames run on one serial queue *per
/// application*: a slow app only delays its own windows,
/// never other apps' frames or the display link. Per window,
/// only the newest frame is kept — while one is waiting to be
/// applied, later frames overwrite it, so a slow app skips
/// intermediate steps instead of falling behind (and the
/// final frame is always the one that lands).
///
/// While an app's windows animate, its
/// `AXEnhancedUserInterface` is switched off: with it on,
/// AppKit performs extra work per frame-set that makes moves
/// visibly stutter. It is restored when the app's last
/// animation ends (see AGENTS.md guardrails).
@MainActor
final class FrameApplier {
    var elementProvider: @MainActor (WindowID) -> AXUIElement? =
        { _ in nil }

    private var animatingPid: [WindowID: pid_t] = [:]
    private var pidCounts: [pid_t: Int] = [:]
    private var queues: [pid_t: DispatchQueue] = [:]
    private let pending = PendingFrames()
    private let recent = RecentApplies()

    /// How long after one of our own frame-sets a window's
    /// move events are still considered self-inflicted. AX
    /// echoes arrive asynchronously, usually well under this.
    private static let echoGrace: TimeInterval = 1.0

    /// Whether we set this window's frame within the echo
    /// grace period. Used to tell the AX echoes of our own
    /// frame-sets apart from user drags — without this, the
    /// echo of a settled animation reads as a drag end (and in
    /// stack layouts, where all slots overlap, that fake drop
    /// swaps windows and retriggers itself forever).
    func didRecentlySetFrame(_ id: WindowID) -> Bool {
        recent.isRecent(id, within: Self.echoGrace)
    }

    // MARK: - Animation lifecycle (EUI management)

    /// Marks a window as animating; disables the app's
    /// EnhancedUserInterface while any of its windows move.
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

    /// Ends a window's animation (settled or cancelled) and
    /// restores EnhancedUserInterface when it was the app's
    /// last moving window.
    func endAnimating(_ id: WindowID) {
        guard let pid = animatingPid.removeValue(forKey: id)
        else { return }
        pidCounts[pid, default: 1] -= 1
        if pidCounts[pid, default: 0] <= 0 {
            pidCounts[pid] = nil
            setEUI(pid: pid, enabled: true)
        }
    }

    // MARK: - Frame application

    /// Hands one frame to the target app's queue. `setSize`
    /// marks the rare frames that change size (a size step and
    /// the final frame); all others apply position
    /// only — a single AX call that never forces the app to
    /// re-lay-out its content.
    func apply(_ id: WindowID, _ frame: CGRect, setSize: Bool) {
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
            // Stamped after the AX call: echoes trail it.
            recent.record(id)
        }
    }

    // MARK: - Internals

    private func queue(for pid: pid_t) -> DispatchQueue {
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

    /// EUI toggles ride the same per-app queue as the frames,
    /// so off → frames → on ordering is guaranteed. Queues are
    /// kept for the app's lifetime; one idle queue per app is
    /// cheaper than risking two queues racing AX calls.
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

/// When each window's frame was last set by us. Written from
/// the per-app queues, read from the main actor.
private final class RecentApplies: @unchecked Sendable {
    private let lock = NSLock()
    private var stamps: [WindowID: TimeInterval] = [:]

    func record(_ id: WindowID) {
        lock.lock()
        defer { lock.unlock() }
        stamps[id] = ProcessInfo.processInfo.systemUptime
    }

    func isRecent(
        _ id: WindowID,
        within interval: TimeInterval
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let stamp = stamps[id] else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        if now - stamp > interval {
            stamps[id] = nil
            return false
        }
        return true
    }
}

/// Latest pending frame per window, shared between the main
/// actor (producer) and the per-app queues (consumers).
/// AXUIElement is thread-safe; the lock guards the dictionary.
private final class PendingFrames: @unchecked Sendable {
    struct Entry {
        let element: AXUIElement
        var frame: CGRect
        var setSize: Bool
    }

    private let lock = NSLock()
    private var entries: [WindowID: Entry] = [:]

    /// Stores the newest frame for a window. Returns true when
    /// an apply is already scheduled (the caller must not
    /// schedule another). A pending size change survives being
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
