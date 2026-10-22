import Foundation

/// Which windows WindowServer reported CREATED while KiwiDesk
/// watched, and when (#2478): the one fact that tells a window an
/// app just opened from one KiwiDesk is only now adopting — a boot
/// sweep, an unlock's heal, a re-track after a dropped removal.
/// `.windowCreated` carries no such provenance; the create
/// notification (#1877) does.
///
/// Fed only by `KiwiCore.windowServerChanged`. Closed by default:
/// until the WindowServer route reports itself active, `isLive`
/// is false and nothing reads as created, so a host without the
/// private route — and every test core — keeps the pre-#2478
/// behaviour.
@MainActor
final class WindowCreateLedger {
    /// How long after its create a window still counts as new:
    /// the launch follow's own bound, which covers a create
    /// adopted by the heal rather than its AX notification
    /// (`LaunchFollowIntent.drainWindow`).
    static let bound: TimeInterval = LaunchFollowIntent.drainWindow

    /// Whether the WindowServer route delivers creates.
    var isLive = false

    private var created: [WindowID: Date] = [:]

    /// Records a create; drops entries past the bound.
    func noteCreated(_ id: WindowID, at now: Date) {
        created = created.filter {
            now.timeIntervalSince($0.value) < Self.bound
        }
        created[id] = now
    }

    /// Forgets a destroyed window, so a reused id is not new.
    func noteDestroyed(_ id: WindowID) {
        created[id] = nil
    }

    /// When `id` was created, while within the bound of `now`;
    /// nil when the route is not live, the window predates it, or
    /// the create is older than the bound.
    func createdAt(_ id: WindowID, now: Date) -> Date? {
        guard isLive, let at = created[id],
            now.timeIntervalSince(at) < Self.bound
        else { return nil }
        return at
    }
}
