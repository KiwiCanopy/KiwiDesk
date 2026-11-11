import Foundation

/// Why a profile applies — the one classification its doors
/// pass, folded from two Bools when a third cause arrived
/// (#1507).
enum ProfileApplyCause {
    /// An explicit user load: the profile's Spaces become
    /// authoritative (stale ones pruned, the sidecar synced) and
    /// the retile forces past the ±2 pt tolerance so a small edit
    /// is not swallowed.
    case explicit
    /// An in-effect edit's re-apply: `explicit`'s prune and force,
    /// without a load's fresh start of the shown Desktops' sizes
    /// (#2921 ruling 6).
    case edit
    /// The post-reload re-apply: forced, prunes nothing.
    case reapply
    /// A Desktop binding's load outside a Desktop switch (a
    /// config load, a bind verb, the bindings write): un-forced,
    /// so AX-echo lag cannot wobble windows.
    case event
    /// A Desktop binding's load inside the Desktop switch handler,
    /// `event` in every way save one: the handler activates the
    /// arriving Space itself, so a restore's follow stands down
    /// (#3191).
    case desktopSwitch
    /// A monitor change: un-forced like `event`, and a departing
    /// Space on a screen that is gone is HELD rather than
    /// forwarded (#1507).
    case monitorChange

    var prunesStale: Bool { self == .explicit || self == .edit }
    var forcesRetile: Bool {
        self == .explicit || self == .edit || self == .reapply
    }
}
