import Foundation

/// A Space's session sizes and the key they are filed under
/// (#2921), read for every Space at once
/// (`sessionSizingOfEverySpace`).
public struct SpaceSizing: Sendable, Equatable {
    public var key: SessionSizingKey
    public var ratios: SessionRatios
}

/// The part of a Space a layout undo puts back (#3515): order,
/// mode and sizing, plus its session sizes and where they are
/// filed. Focus, the scroll rest and the run ends are left out —
/// a retile rewrites them, so a step holding them would never
/// match the Space again — and so is the Maximize, whose end and
/// return are its own doors' (#2676).
public struct SpaceArrangement: Sendable, Equatable {
    public var mode: LayoutMode
    public var windows: [WindowID]
    public var stackWeights: [WindowID: Double]
    public var runSizes: [WindowID: RunSize]
    public var trackBreaks: Set<WindowID>
    public var handedBreaks: Set<WindowID>
    public var trackWeights: [WindowID: Double]
    /// A step taken under another Desktop or arrangement has
    /// another key, so it never matches after a switch or apply.
    public var sizing: SpaceSizing

    public init(_ space: Space, sizing: SpaceSizing) {
        mode = space.mode
        windows = space.windows
        stackWeights = space.stackWeights
        runSizes = space.runSizes
        trackBreaks = space.trackBreaks
        handedBreaks = space.handedBreaks
        trackWeights = space.trackWeights
        self.sizing = sizing
    }
}

extension Space {
    /// Puts `arrangement`'s order and sizing back (#3515) — a
    /// reorder, so it releases the scroll slot (#1353) and ends the
    /// Maximize. The mode is the caller's, through `setSpaceMode`;
    /// the members must already be this Space's, or nothing is
    /// written and it answers false.
    @discardableResult
    public mutating func restore(_ arrangement: SpaceArrangement) -> Bool {
        guard Set(arrangement.windows) == Set(windows) else {
            return false
        }
        windows = arrangement.windows
        stackWeights = arrangement.stackWeights
        runSizes = arrangement.runSizes
        trackBreaks = arrangement.trackBreaks
        handedBreaks = arrangement.handedBreaks
        trackWeights = arrangement.trackWeights
        releaseScrollSlot()
        endMaximize()
        return true
    }
}
