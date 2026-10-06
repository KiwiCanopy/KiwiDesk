import Foundation
import KiwiDeskCore

/// When the slow-boot notice shows and leaves (#1715): only past
/// the threshold, and once shown at least `minimumShown`, so it
/// never flickers. Pure over uptime seconds so a test drives it
/// without a clock.
struct BootNoticeTimeline: Equatable {
    /// Boot that reaches ready sooner never sees the notice; at
    /// 1 s it would flash on ordinary desks (owner ruling).
    static let threshold: TimeInterval = 2
    static let minimumShown: TimeInterval = 1

    /// When boot left `.idle`, not process launch, so a delayed
    /// Accessibility grant does not count.
    private(set) var began: TimeInterval?
    private(set) var shownAt: TimeInterval?
    private(set) var ready = false

    /// Feeds a phase change; returns when the notice is due, if a
    /// show should be scheduled now.
    mutating func phase(
        _ phase: BootPhase,
        at now: TimeInterval
    ) -> TimeInterval? {
        switch phase {
        case .idle:
            return nil
        case .scanning:
            ready = false
            guard began == nil else { return nil }
            began = now
            return now + Self.threshold
        case .ready:
            ready = true
            return nil
        }
    }

    /// Whether a due show still applies: boot has not finished.
    func showsAt(_ now: TimeInterval) -> Bool {
        guard let began, !ready, shownAt == nil else { return false }
        return now >= began + Self.threshold
    }

    mutating func shown(at now: TimeInterval) {
        shownAt = now
    }

    /// When a shown notice may leave once boot is ready.
    func hideTime(readyAt now: TimeInterval) -> TimeInterval? {
        guard let shownAt else { return nil }
        return max(now, shownAt + Self.minimumShown)
    }
}
