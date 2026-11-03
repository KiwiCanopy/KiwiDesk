import ApplicationServices
import CoreGraphics
import Foundation

/// Instant-set target frames awaiting AX echo (#881).
final class InstantTargets: @unchecked Sendable {
    private typealias Entry = (frame: CGRect, at: TimeInterval)
    private let lock = NSLock()
    private var entries: [WindowID: Entry] = [:]
    /// Each standing lead's stamp, until its echo or its lapse.
    private var owedLapses: [WindowID: TimeInterval] = [:]

    func record(_ id: WindowID, frame: CGRect, now: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        entries[id] = (frame, now)
        owedLapses[id] = now
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
        owedLapses[id] = nil
    }

    /// Drops the owed lapses whose grace has passed (#2882):
    /// whether any did, and the seconds until the next one is due.
    /// Kept apart from `entries`, which a reader's expiry drops, so
    /// no read can swallow a lapse; an echo's `clear` or a newer
    /// `record` retires one.
    func sweepLapses(
        within interval: TimeInterval,
        now: TimeInterval
    ) -> (lapsed: Bool, nextIn: TimeInterval?) {
        lock.lock()
        defer { lock.unlock() }
        let due = owedLapses.filter { now - $0.value > interval }
        for id in due.keys { owedLapses[id] = nil }
        let next = owedLapses.values.min().map {
            max(interval - (now - $0), 0)
        }
        return (!due.isEmpty, next)
    }
}

/// Recent frame application timestamps for echo suppression.
final class RecentApplies: @unchecked Sendable {
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

    /// Seconds since the window's last stamp, nil without one.
    func age(_ id: WindowID, now: TimeInterval) -> TimeInterval? {
        lock.lock()
        defer { lock.unlock() }
        return stamps[id].map { now - $0 }
    }
}

/// Pending frames per window shared across threads.
final class PendingFrames: @unchecked Sendable {
    struct Entry {
        let element: AXUIElement
        var frame: CGRect
        var setSize: Bool
        /// The screen whose edge band the size write clears
        /// (#2894).
        var band: CGRect? = nil
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
            // The newer frame's band, else the waiting write's
            // where the newer frame still ends in it: the waiting
            // shrink never ran, so the window may still need it.
            merged.band = EdgeBandWrite.mergedBand(
                newer: entry.band,
                waiting: existing.band,
                frame: entry.frame
            )
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
