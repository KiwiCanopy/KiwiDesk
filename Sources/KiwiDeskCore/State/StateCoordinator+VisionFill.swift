import Foundation

/// What KiwiVision's maximize asks while KiwiVision is on (#3064):
/// the shape it fills on the active Space's screen, resolved by
/// `KiwiCore.maximizeShape(from:for:)`, the hand press's one reader
/// of the share a press takes on that Space (#3090).
public struct VisionFill: Equatable, Sendable {
    public var shape: MaximizeShape

    public init(shape: MaximizeShape) { self.shape = shape }
}

/// KiwiVision's maximize as state holds it: what the session asks,
/// mirrored in by `KiwiCore.refillVision`, and the windows the last
/// retire saw filled — never which window fills, which is derived.
public struct VisionFillState: Equatable, Sendable {
    /// nil while KiwiVision is off or its maximize is Off.
    public internal(set) var fill: VisionFill?
    /// What `retireVisionFill` last saw filled: names the windows a
    /// change moved, and is the verdict's memory while a float holds
    /// the focus. Only that retire and the re-key write it.
    var drawn: Set<WindowID> = []
}

/// The derived verdict (#3064): the active Space's focused tiled
/// window fills while KiwiVision's maximize stands, never stored per
/// Space and never through `Space.maximized`, so it follows focus
/// by what it means and lasts across Space switches as KiwiVision
/// does. A hand Maximize outranks it (`maximizedWindow(of:)`).
extension StateCoordinator {
    /// Whether KiwiVision's maximize stands on `space`: asked, the
    /// active Space — the one holding the system focus, so on two
    /// screens one window fills — and a tiled layout other than
    /// Monocle, where one window already fills the screen.
    public func visionFillStands(on space: Space) -> Bool {
        guard visionFill.fill != nil, space.id == workspaces.activeSpace
        else { return false }
        let mode = placementMode(of: space)
        return mode != .floating && mode != .monocle
    }

    /// The window KiwiVision's maximize fills on `space`: its focus
    /// anchor while drawn tiled; while a float holds the focus, the
    /// tiled window it last drew keeps it, else the one focused
    /// last (owner, 2026-11-09; a float never fills until #3036).
    public func visionFilledWindow(of space: Space) -> WindowID? {
        guard visionFillStands(on: space) else { return nil }
        let tiled = effectiveTiledMembers(of: space)
        guard let anchor = focusAnchor(of: space, tiled: tiled) else {
            return nil
        }
        if tiled.contains(anchor) { return anchor }
        if let kept = tiled.first(where: visionFill.drawn.contains) {
            return kept
        }
        let last = tiled.max {
            focusRecencyRank(of: $0) < focusRecencyRank(of: $1)
        }
        return last.flatMap { focusRecencyRank(of: $0) > 0 ? $0 : nil }
    }

    /// What KiwiVision's maximize fills on `space`.
    func visionFillShape(of space: Space) -> MaximizeShape? {
        visionFillStands(on: space) ? visionFill.fill?.shape : nil
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

extension StateCoordinator {
    /// A native-tab re-key of a window `drawn` names (#308).
    mutating func rekeyVisionFill(_ old: WindowID, to new: WindowID) {
        if visionFill.drawn.remove(old) != nil {
            visionFill.drawn.insert(new)
        }
    }
}
