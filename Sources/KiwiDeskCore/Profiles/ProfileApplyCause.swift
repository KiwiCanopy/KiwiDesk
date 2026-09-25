import Foundation

/// Why a profile applies — the one classification its doors
/// pass, folded from two Bools when a third cause arrived
/// (#1507).
enum ProfileApplyCause {
    /// An explicit user load or an in-effect edit: the profile's
    /// Spaces become authoritative (stale ones pruned, the
    /// sidecar synced) and the retile forces past the ±2 pt
    /// tolerance so a small edit is not swallowed.
    case explicit
    /// The post-reload re-apply: forced, prunes nothing.
    case reapply
    /// A Desktop binding switch: un-forced, so AX-echo lag
    /// cannot wobble windows.
    case event
    /// A monitor change: un-forced like `event`, and a departing
    /// Space on a screen that is gone is HELD rather than
    /// forwarded (#1507).
    case monitorChange

    var prunesStale: Bool { self == .explicit }
    var forcesRetile: Bool { self == .explicit || self == .reapply }
}
