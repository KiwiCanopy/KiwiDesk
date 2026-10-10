import Foundation
import KiwiDeskCore

/// Every decision the slow-boot notice makes (#1715), pure over
/// uptime seconds so a test drives it without a clock or a panel:
/// it shows only past the threshold, stays at least
/// `minimumShown` so it never flickers, stands down for good once
/// a stand-down meets it, and starts over with each boot. A
/// restart restore (#2133) keeps it up past ready until it ends.
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
    /// A restart restore still places windows (#2133): the notice
    /// outlives ready until it ends.
    private(set) var restoring = false

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
            if restoring { return .none }
            guard let shownAt, !stoodDown else { return .cancel }
            return .hideAt(max(now, shownAt + Self.minimumShown))
        }
    }

    /// Feeds the restore's progress (#2133). Placing keeps the
    /// notice due past ready, its show still waiting out the
    /// threshold from boot's start so a fast restore never flashes;
    /// done holds the end line `minimumShown`; none hides at once.
    mutating func restore(
        _ phase: RestorePhase,
        at now: TimeInterval,
        standsDown: Bool
    ) -> Effect {
        if standsDown, phase != .none {
            restoring = !isDone(phase)
            stoodDown = true
            return shownAt != nil ? .hideNow : .cancel
        }
        switch phase {
        case .placing:
            let wasRestoring = restoring
            restoring = true
            guard !wasRestoring, shownAt == nil, !stoodDown,
                let began
            else { return .none }
            return .showAt(max(now, began + Self.threshold))
        case .done:
            guard restoring else { return .none }
            restoring = false
            // Boot's own show still stands until ready.
            guard ready else { return .none }
            guard let shownAt, !stoodDown else { return .cancel }
            return .hideAt(
                max(now + Self.minimumShown, shownAt + Self.minimumShown)
            )
        case .none:
            guard restoring else { return .none }
            restoring = false
            return shownAt != nil ? .hideNow : .cancel
        }
    }

    /// Whether a due show applies: past the threshold, boot still
    /// running, nothing standing it down.
    func showsAt(_ now: TimeInterval, standsDown: Bool) -> Bool {
        guard let began, !ready || restoring, shownAt == nil,
            !stoodDown, !standsDown
        else { return false }
        return now >= began + Self.threshold
    }

    mutating func shown(at now: TimeInterval) {
        shownAt = now
    }

    private func isDone(_ phase: RestorePhase) -> Bool {
        if case .done = phase { return true }
        return false
    }
}
