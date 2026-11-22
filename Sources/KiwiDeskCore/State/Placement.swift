import CoreGraphics
import Foundation

/// A placement target (#3517): one area of a connected physical
/// screen — the whole screen when it is not split. Session-only and
/// never stored: what is stored is the area's `ScreenAreaKey`. A
/// reconnect under a new `DisplayID` mints new ids from the same
/// fingerprint.
public struct PlacementID: Hashable, Sendable, CustomStringConvertible {
    public let display: DisplayID
    /// The area's `ScreenArea.id`, never its place in the list.
    public let area: Int

    /// Built only by `WorkspaceManager.rebuildPlacements` and the key
    /// resolver (`PlacementConstructionCensusTests`).
    init(display: DisplayID, area: Int) {
        self.display = display
        self.area = area
    }

    public var description: String { "\(display)/area\(area)" }
}

/// One placement target: an area of a physical screen.
public struct Placement: Sendable, Equatable {
    public let id: PlacementID
    /// The area as stored, its rect in the screen's own points.
    public let area: ScreenArea
    /// The stored identity a pin or a per-screen map keys by.
    public let key: ScreenAreaKey
    /// The area's frame in AppKit global coordinates (y up), like
    /// `Display.frame`.
    public let frame: CGRect

    /// The physical screen this area is part of.
    public var display: DisplayID { id.display }

    /// `area`'s frame in AppKit coordinates on `screen`: the stored
    /// rect is top-left, y down, so its top sits `y` below the
    /// screen's top edge.
    static func frame(of area: ScreenArea, on screen: CGRect) -> CGRect {
        CGRect(
            x: screen.minX + CGFloat(area.x),
            y: screen.maxY - CGFloat(area.y + area.h),
            width: CGFloat(area.w),
            height: CGFloat(area.h)
        )
    }
}
