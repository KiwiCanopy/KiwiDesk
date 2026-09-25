import CoreGraphics
import Foundation

/// The App Bar's own look and behavior (monocle, scrolling).
/// Where it sits and the look both bars share are `KiwiShelf`'s
/// (#1517); a drawing reads `AppBarLook`.
public struct AppBarStyle: Sendable, Equatable {
    /// Edge mark by default, where the Space Bar's is Outline:
    /// the indicator's SHAPE is what tells the sections apart
    /// (#1517).
    public var activeIndicator: ActiveIndicator = .edgeMark
    public var content: Content = .iconAndTitle
    /// Longest title drawn per item before tail-truncation (#1171).
    public var titleCap = 10
    /// Group adjacent windows of the same app with a count badge.
    public var groupAdjacentWindows = true

    public init() {}

    /// Clamps dim factor to valid range [0.05, 1.0].
    public static func clampDim(_ value: CGFloat) -> CGFloat {
        max(0.05, min(value, 1))
    }
}

extension AppBarStyle: Codable {
}
