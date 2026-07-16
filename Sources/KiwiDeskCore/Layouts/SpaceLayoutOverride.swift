import Foundation

/// A per-space layout override map value (issue #17). Every
/// layout's override struct is an optional mirror of its global
/// params: nil inherits the global value, a value overrides just
/// that field for one space. This marker lets one generic GUI
/// binding helper drive all five override editors instead of five
/// near-identical copies — the shared domain concept, kept minimal
/// per AGENTS.md §2.4 (no heavy generics).
public protocol SpaceLayoutOverride: Equatable, Sendable {
    init()
    /// True when no field is set — an empty override is dropped so
    /// the stored map stays sparse.
    var isEmpty: Bool { get }
}

extension SpaceLayoutOverride {
    /// How many fields this override actually sets. Every stored
    /// property is an optional mirror of a global param, so a
    /// non-nil child is one overridden field. Discovered by
    /// reflection rather than hand-listed, so a newly added
    /// override field is counted automatically (the §5 "reflection
    /// net"): it drives the `Overrides…` button's saved-field
    /// count and the dormant-layout disclosure (#290) without a
    /// per-layout tally that could silently drift.
    public var fieldCount: Int {
        var count = 0
        for child in Mirror(reflecting: self).children {
            // Each field is an Optional: a `.some` mirrors exactly
            // one child, `nil` mirrors none — so a non-empty
            // optional child is one set field. `fieldCount == 0`
            // therefore matches `isEmpty` by construction.
            let mirror = Mirror(reflecting: child.value)
            if mirror.displayStyle == .optional,
                !mirror.children.isEmpty
            {
                count += 1
            }
        }
        return count
    }
}

extension ScrollingOverride: SpaceLayoutOverride {}
extension BspOverride: SpaceLayoutOverride {}
extension StackOverride: SpaceLayoutOverride {}
extension GridOverride: SpaceLayoutOverride {}
extension MonocleOverride: SpaceLayoutOverride {}
extension TrackOverride: SpaceLayoutOverride {}
