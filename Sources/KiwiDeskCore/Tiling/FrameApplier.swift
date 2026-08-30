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

    /// True if window's frame was set within echo grace period.
    func didRecentlySetFrame(_ id: WindowID) -> Bool {
        recent.isRecent(id, within: Self.echoGrace)
    }

    /// Commanded frame from recent `applyInstant` while echo is in flight
    /// (#881).
    func instantTarget(_ id: WindowID) -> CGRect? {
        instantTargets.frame(id, within: Self.echoGrace)
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
            recent.record(id)
        }
    }

    /// Applies frame instantly dropping EUI around the set (#881).
    func applyInstant(_ id: WindowID, _ frame: CGRect) {
        instantTargets.record(id, frame: frame)
        guard let element = elementProvider(id) else { return }
        guard
            let pid = animatingPid[id] ?? Self.pid(of: element)
        else { return }
        nonisolated(unsafe) let target = element
        let recent = recent
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
            recent.record(id)
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

    func record(_ id: WindowID, frame: CGRect) {
        lock.lock()
        defer { lock.unlock() }
        entries[id] = (
            frame,
            ProcessInfo.processInfo.systemUptime
        )
    }

    func frame(
        _ id: WindowID,
        within interval: TimeInterval
    ) -> CGRect? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries[id] else { return nil }
        let now = ProcessInfo.processInfo.systemUptime
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

/// Pending frames per window shared across threads.
private final class PendingFrames: @unchecked Sendable {
    struct Entry {
        let element: AXUIElement
        var frame: CGRect
        var setSize: Bool
    }

    private let lock = NSLock()
    private var entries: [WindowID: Entry] = [:]

    /// Stores newest frame; returns true if an apply was already scheduled.
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
