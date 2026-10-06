import Foundation
import KiwiDeskCore

/// Every decision the slow-boot notice makes (#1715), pure over
/// uptime seconds so a test drives it without a clock or a panel:
/// it shows only past the threshold, stays at least
/// `minimumShown` so it never flickers, stands down for good once
/// a stand-down meets it, and starts over with each boot.
struct BootNoticeTimeline: Equatable {
    /// Boot that reaches ready sooner never sees the notice. A warm
    /// boot of a 50-app desk measured 2.1–2.7 s, so 2 s flashed it
    /// on every relaunch (owner ruling 2026-10-07).
    static let threshold: TimeInterval = 3
    static let minimumShown: TimeInterval = 1

    /// What the controller does next.
    enum Effect: Equatable {
        case none
        /// Ask `showsAt` again at this time.
        case showAt(TimeInterval)
        /// Drop a pending show; nothing is up.
        case cancel
        case hideAt(TimeInterval)
        case hideNow
    }

    /// When boot left `.idle`, not process launch, so a delayed
    /// Accessibility grant does not count.
    private(set) var began: TimeInterval?
    private(set) var shownAt: TimeInterval?
    private(set) var ready = false
    /// A stand-down met this boot: it does not show again.
    private(set) var stoodDown = false

    /// Feeds a phase change. `standsDown` is whether anything
    /// stands the notice down right now.
    mutating func phase(
        _ phase: BootPhase,
        at now: TimeInterval,
        standsDown: Bool
    ) -> Effect {
        switch phase {
        case .idle:
            // A stop (a revoked grant) ends this boot; the next
            // start is a boot of its own.
            let wasShown = shownAt != nil
            self = BootNoticeTimeline()
            return wasShown ? .hideNow : .cancel
        case .scanning:
            ready = false
            if standsDown {
                stoodDown = true
                return shownAt != nil ? .hideNow : .cancel
            }
            guard began == nil else { return .none }
            began = now
            return .showAt(now + Self.threshold)
        case .ready:
            ready = true
            guard let shownAt, !stoodDown else { return .cancel }
            return .hideAt(max(now, shownAt + Self.minimumShown))
        }
    }

    /// Whether a due show applies: past the threshold, boot still
    /// running, nothing standing it down.
    func showsAt(_ now: TimeInterval, standsDown: Bool) -> Bool {
        guard let began, !ready, shownAt == nil, !stoodDown,
            !standsDown
        else { return false }
        return now >= began + Self.threshold
    }

    mutating func shown(at now: TimeInterval) {
        shownAt = now
    }
}
