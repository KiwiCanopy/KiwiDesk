import Foundation

/// What KiwiVision's maximize asks while KiwiVision is on (#3064):
/// the axis, and the Layout Defaults table its shape reads.
public struct VisionFill: Equatable, Sendable {
    /// The axis a directional fill takes, nil for the whole screen.
    public var axis: MaximizeAxis?
    /// The shares and anchors per screen shape (`maximize.*`).
    public var maximize: MaximizeSettings
    /// The shape of a Space whose screen state does not track.
    public var fallbackShape: ScreenShape

    public init(
        axis: MaximizeAxis?,
        maximize: MaximizeSettings,
        fallbackShape: ScreenShape
    ) {
        self.axis = axis
        self.maximize = maximize
        self.fallbackShape = fallbackShape
    }
}

/// KiwiVision's maximize as state holds it: what the session asks,
/// mirrored in by `KiwiCore.refillVision`, and the windows the last
/// retire saw filled — never which window fills, which is derived.
public struct VisionFillState: Equatable, Sendable {
    /// nil while KiwiVision is off or its maximize is Off.
    public internal(set) var fill: VisionFill?
    /// What `retireVisionFill` last saw filled, read only to name
    /// the windows a change moved; a re-keyed id reads as one
    /// change naming a window that no longer exists.
    var drawn: Set<WindowID> = []
}

/// The derived verdict (#3064): the focused tiled window of every
/// Space fills while KiwiVision's maximize stands, never stored per
/// Space and never through `Space.maximized`, so it follows focus
/// by what it means and lasts across Space switches as KiwiVision
/// does. A hand Maximize outranks it (`maximizedWindow(of:)`).
extension StateCoordinator {
    /// Whether KiwiVision's maximize stands on `space`: asked, and a
    /// tiled layout other than Monocle, where one window already
    /// fills the screen.
    public func visionFillStands(on space: Space) -> Bool {
        guard visionFill.fill != nil else { return false }
        let mode = placementMode(of: space)
        return mode != .floating && mode != .monocle
    }

    /// The window KiwiVision's maximize fills on `space`: its focus
    /// anchor while drawn tiled, never a float (#3036), or nil.
    public func visionFilledWindow(of space: Space) -> WindowID? {
        guard visionFillStands(on: space) else { return nil }
        let tiled = effectiveTiledMembers(of: space)
        guard let anchor = focusAnchor(of: space, tiled: tiled),
            tiled.contains(anchor)
        else { return nil }
        return anchor
    }

    /// What KiwiVision's maximize fills on `space`, at the share
    /// and anchor Layout Defaults store for its screen's shape.
    func visionFillShape(of space: Space) -> MaximizeShape? {
        guard let fill = visionFill.fill else { return nil }
        guard let axis = fill.axis else { return .full }
        let shape =
            workspaces.display(of: space.id)
            .flatMap { workspaces.displays[$0] }
            .map(ScreenShape.of) ?? fill.fallbackShape
        return MaximizeShape(
            axis: axis,
            share: fill.maximize.share(for: axis, on: shape),
            anchor: fill.maximize.anchor[shape]
        )
    }

    /// Mirrors what KiwiVision asks; true where it changed.
    mutating func setVisionFill(_ fill: VisionFill?) -> Bool {
        guard visionFill.fill != fill else { return false }
        visionFill.fill = fill
        return true
    }

    /// The windows whose KiwiVision fill began or ended since the
    /// last call — the window left and the window arriving, as a
    /// follow's re-point names them (#3063).
    mutating func retireVisionFill() -> [WindowID] {
        let now = Set(
            workspaces.allSpaces.compactMap {
                handMaximizedWindow(of: $0) == nil
                    ? visionFilledWindow(of: $0) : nil
            }
        )
        let changed = now.symmetricDifference(visionFill.drawn)
        visionFill.drawn = now
        return changed.sorted { $0.raw < $1.raw }
    }
}
