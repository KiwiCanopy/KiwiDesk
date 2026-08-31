import Foundation

/// Protocol for per-space layout override parameter maps (#17).
public protocol SpaceLayoutOverride: Equatable, Sendable {
    init()
    /// True when no override fields are populated.
    var isEmpty: Bool { get }
}

extension SpaceLayoutOverride {
    /// Counts overridden fields via reflection (#290) — the §5
    /// reflection net: a newly added override field is counted
    /// automatically, no per-layout tally to drift. Each field is
    /// an Optional: `.some` mirrors one child, nil none, so
    /// `fieldCount == 0` matches `isEmpty` by construction.
    public var fieldCount: Int {
        var count = 0
        for child in Mirror(reflecting: self).children {
            let mirror = Mirror(reflecting: child.value)
            if mirror.displayStyle == .optional,
                !mirror.children.isEmpty
            {
                count += 1
            }
        }
        return count
    }

    /// Total override field capacity for the layout mode (#678 8b).
    public var fieldCapacity: Int {
        Mirror(reflecting: self).children.count
    }
}

extension ScrollingOverride: SpaceLayoutOverride {}
extension BspOverride: SpaceLayoutOverride {}
extension StackOverride: SpaceLayoutOverride {}
extension GridOverride: SpaceLayoutOverride {}
extension MonocleOverride: SpaceLayoutOverride {}
extension TrackOverride: SpaceLayoutOverride {}

extension LayoutMode {
    /// Total number of override fields exposed by layout mode (#678 8b).
    public var overrideFieldCapacity: Int {
        switch self {
        case .scrolling: return ScrollingOverride().fieldCapacity
        case .bsp: return BspOverride().fieldCapacity
        case .stack: return StackOverride().fieldCapacity
        case .grid: return GridOverride().fieldCapacity
        case .monocle: return MonocleOverride().fieldCapacity
        case .track: return TrackOverride().fieldCapacity
        case .floating: return 0
        }
    }
}
