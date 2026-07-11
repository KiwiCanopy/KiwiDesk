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

extension ScrollingOverride: SpaceLayoutOverride {}
extension BspOverride: SpaceLayoutOverride {}
extension StackOverride: SpaceLayoutOverride {}
extension GridOverride: SpaceLayoutOverride {}
extension MonocleOverride: SpaceLayoutOverride {}
extension TrackOverride: SpaceLayoutOverride {}
